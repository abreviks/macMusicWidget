import Foundation
import AppKit
import Combine
import WidgetKit

// MARK: - Monitor

class NowPlayingMonitor: ObservableObject {
    @Published var isActive = false
    @Published var currentData: NowPlayingData = .empty

    private var observer: NSObjectProtocol?
    private var commandWatchTimer: Timer?

    init() {
        startMonitoring()
    }

    deinit {
        stopMonitoring()
    }

    func startMonitoring() {
        guard observer == nil else { return }

        observer = DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("com.apple.Music.playerInfo"),
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handlePlayerNotification(notification)
        }

        // Snapshot the current command file so we don't replay stale commands
        if let url = AppGroupConstants.commandFileURL {
            lastCommandContent = try? String(contentsOf: url, encoding: .utf8)
        }

        // Poll the command file for widget control commands
        commandWatchTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkForCommand()
        }

        isActive = true
        fetchCurrentState()
    }

    func stopMonitoring() {
        if let observer {
            DistributedNotificationCenter.default().removeObserver(observer)
        }
        commandWatchTimer?.invalidate()
        observer = nil
        commandWatchTimer = nil
        isActive = false
    }

    // MARK: - Command relay from widget

    private var lastCommandContent: String?

    private func checkForCommand() {
        guard let url = AppGroupConstants.commandFileURL,
              let content = try? String(contentsOf: url, encoding: .utf8),
              content != lastCommandContent else { return }
        lastCommandContent = content

        guard let command = content.components(separatedBy: "|").first else { return }

        switch command {
        case "playpause":
            simulateMediaKey(16) // NX_KEYTYPE_PLAY
        case "next":
            simulateMediaKey(17) // NX_KEYTYPE_NEXT
        case "previous":
            simulateMediaKey(18) // NX_KEYTYPE_PREVIOUS
        default:
            break
        }
    }

    private func simulateMediaKey(_ keyType: Int32) {
        func postKeyEvent(down: Bool) {
            let flags = NSEvent.ModifierFlags(rawValue: 0xa00)
            let data1 = Int((Int(keyType) << 16) | ((down ? 0xa : 0xb) << 8))
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8,
                data1: data1,
                data2: -1
            )
            event?.cgEvent?.post(tap: .cgSessionEventTap)
        }
        postKeyEvent(down: true)
        postKeyEvent(down: false)
    }

    // MARK: - Notification handling

    private func handlePlayerNotification(_ notification: Notification) {
        guard let info = notification.userInfo else { return }

        let playerState = info["Player State"] as? String ?? "Stopped"

        if playerState == "Stopped" {
            currentData = .empty
            SharedDataStore.write(.empty)
            SharedDataStore.writeAlbumArt(nil)
            lastArtworkQuery = nil
            WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConstants.widgetKind)
            return
        }

        let title = info["Name"] as? String ?? ""
        let artist = info["Artist"] as? String ?? ""
        let album = info["Album"] as? String ?? ""
        let totalTimeMs = info["Total Time"] as? Double ?? 0
        let locationSec = info["Location"] as? Double ?? 0

        let data = NowPlayingData(
            title: title,
            artist: artist,
            album: album,
            isPlaying: playerState == "Playing",
            duration: totalTimeMs / 1000.0,
            elapsedTime: locationSec,
            timestamp: Date()
        )

        currentData = data
        SharedDataStore.write(data)
        fetchArtwork(artist: artist, album: album)
        WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConstants.widgetKind)
    }

    // MARK: - Initial state fetch

    private func fetchCurrentState() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            let script = """
            tell application "Music"
                if player state is playing or player state is paused then
                    set t to name of current track
                    set a to artist of current track
                    set al to album of current track
                    set d to duration of current track
                    set p to player position
                    set s to (player state is playing) as text
                    return t & "||" & a & "||" & al & "||" & d & "||" & p & "||" & s
                end if
            end tell
            """

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", script]
            let pipe = Pipe()
            process.standardOutput = pipe
            process.standardError = Pipe()

            var data: NowPlayingData?

            if let _ = try? process.run() {
                process.waitUntilExit()
                let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                let parts = output.components(separatedBy: "||")
                if parts.count >= 6 {
                    data = NowPlayingData(
                        title: parts[0],
                        artist: parts[1],
                        album: parts[2],
                        isPlaying: parts[5] == "true",
                        duration: Double(parts[3]) ?? 0,
                        elapsedTime: Double(parts[4]) ?? 0,
                        timestamp: Date()
                    )
                }
            }

            // Fall back to last saved data
            if data == nil {
                data = SharedDataStore.readNowPlayingData()
            }

            guard let data, data.title != "Not Playing", !data.title.isEmpty else { return }

            DispatchQueue.main.async {
                self?.currentData = data
                SharedDataStore.write(data)
                self?.fetchArtwork(artist: data.artist, album: data.album)
            }
        }
    }

    // MARK: - Artwork via iTunes Search API

    private var lastArtworkQuery: String?

    private func fetchArtwork(artist: String, album: String) {
        let query = "\(artist) \(album)".trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty, query != lastArtworkQuery else { return }
        lastArtworkQuery = query

        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed),
              let url = URL(string: "https://itunes.apple.com/search?term=\(encoded)&entity=album&limit=1")
        else { return }

        URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let results = json["results"] as? [[String: Any]],
                  let first = results.first,
                  let artUrlString = first["artworkUrl100"] as? String else { return }

            // Request higher resolution (600x600)
            let hiRes = artUrlString.replacingOccurrences(of: "100x100", with: "600x600")
            guard let artUrl = URL(string: hiRes) else { return }

            URLSession.shared.dataTask(with: artUrl) { [weak self] imgData, _, _ in
                guard let imgData else { return }
                let resized = self?.resizeArtwork(imgData, maxSize: 300)
                SharedDataStore.writeAlbumArt(resized ?? imgData)
                DispatchQueue.main.async {
                    WidgetCenter.shared.reloadTimelines(ofKind: AppGroupConstants.widgetKind)
                }
            }.resume()
        }.resume()
    }

    private func resizeArtwork(_ data: Data, maxSize: CGFloat) -> Data? {
        guard let image = NSImage(data: data) else { return data }
        let size = image.size
        guard size.width > maxSize || size.height > maxSize else { return data }

        let scale = maxSize / max(size.width, size.height)
        let newSize = NSSize(width: size.width * scale, height: size.height * scale)

        let resized = NSImage(size: newSize)
        resized.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: newSize),
                   from: NSRect(origin: .zero, size: size),
                   operation: .copy, fraction: 1.0)
        resized.unlockFocus()

        guard let tiff = resized.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            return data
        }
        return png
    }
}
