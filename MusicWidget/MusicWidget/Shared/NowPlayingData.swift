import Foundation

struct NowPlayingData: Codable, Equatable {
    let title: String
    let artist: String
    let album: String
    let isPlaying: Bool
    let duration: TimeInterval
    let elapsedTime: TimeInterval
    let timestamp: Date

    static let empty = NowPlayingData(
        title: "Not Playing",
        artist: "",
        album: "",
        isPlaying: false,
        duration: 0,
        elapsedTime: 0,
        timestamp: Date()
    )
}
