import Foundation

enum AppGroupConstants {
    static let widgetKind = "MusicWidgetExtension"
    static let extensionBundleID = "com.macmusic.macMusic.MusicWidgetExtension"
    static let nowPlayingFileName = "nowplaying.json"
    static let albumArtFileName = "albumart.png"
    static let commandFileName = "command.txt"
    static let sharedDirName = "MusicWidgetShared"

    static var sharedContainerURL: URL? {
        let dir: URL
        if isSandboxed {
            // Extension: use Documents inside our own sandbox container
            let docs = FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent("Documents")
                .appendingPathComponent(sharedDirName)
            dir = docs
        } else {
            // Main app (unsandboxed): write into the extension's container
            let realHome = NSHomeDirectory()
            dir = URL(fileURLWithPath: realHome)
                .appendingPathComponent("Library/Containers")
                .appendingPathComponent(extensionBundleID)
                .appendingPathComponent("Data/Documents")
                .appendingPathComponent(sharedDirName)
        }
        if !FileManager.default.fileExists(atPath: dir.path) {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    static var nowPlayingFileURL: URL? {
        sharedContainerURL?.appendingPathComponent(nowPlayingFileName)
    }

    static var albumArtFileURL: URL? {
        sharedContainerURL?.appendingPathComponent(albumArtFileName)
    }

    static var commandFileURL: URL? {
        sharedContainerURL?.appendingPathComponent(commandFileName)
    }

    private static var isSandboxed: Bool {
        ProcessInfo.processInfo.environment["APP_SANDBOX_CONTAINER_ID"] != nil
    }
}
