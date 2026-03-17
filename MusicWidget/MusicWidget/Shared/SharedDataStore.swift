import Foundation

enum SharedDataStore {
    private static let encoder = JSONEncoder()
    private static let decoder = JSONDecoder()

    static func write(_ data: NowPlayingData) {
        guard let url = AppGroupConstants.nowPlayingFileURL else { return }
        do {
            let encoded = try encoder.encode(data)
            try encoded.write(to: url, options: .atomic)
        } catch {
            print("Failed to write now playing data: \(error)")
        }
    }

    static func writeAlbumArt(_ imageData: Data?) {
        guard let url = AppGroupConstants.albumArtFileURL else { return }
        if let imageData {
            try? imageData.write(to: url, options: .atomic)
        } else {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func readNowPlayingData() -> NowPlayingData? {
        guard let url = AppGroupConstants.nowPlayingFileURL,
              let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(NowPlayingData.self, from: data)
    }

    static func readAlbumArt() -> Data? {
        guard let url = AppGroupConstants.albumArtFileURL else { return nil }
        return try? Data(contentsOf: url)
    }

    static func writeCommand(_ command: String) {
        guard let url = AppGroupConstants.commandFileURL else { return }
        // Include timestamp to ensure file always changes
        let content = "\(command)|\(Date().timeIntervalSince1970)"
        try? content.write(to: url, atomically: true, encoding: .utf8)
    }

    static func readCommand() -> String? {
        guard let url = AppGroupConstants.commandFileURL,
              let content = try? String(contentsOf: url, encoding: .utf8) else { return nil }
        let parts = content.components(separatedBy: "|")
        return parts.first
    }
}
