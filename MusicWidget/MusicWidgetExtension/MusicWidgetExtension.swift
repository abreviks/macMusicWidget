import WidgetKit
import SwiftUI
import AppKit
import AppIntents

// MARK: - Timeline

struct MusicEntry: TimelineEntry {
    let date: Date
    let data: NowPlayingData
    let albumArt: Data?
}

struct MusicTimelineProvider: TimelineProvider {
    typealias Entry = MusicEntry

    func placeholder(in context: Context) -> MusicEntry {
        MusicEntry(date: Date(), data: .empty, albumArt: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (MusicEntry) -> Void) {
        completion(readCurrentEntry())
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<MusicEntry>) -> Void) {
        let entry = readCurrentEntry()
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30)))
        completion(timeline)
    }

    private func readCurrentEntry() -> MusicEntry {
        let data = SharedDataStore.readNowPlayingData() ?? .empty
        let artData = data.title.isEmpty || data.title == "Not Playing" ? nil : SharedDataStore.readAlbumArt()
        return MusicEntry(date: Date(), data: data, albumArt: artData)
    }
}

// MARK: - Widget

struct MusicWidgetExtension: Widget {
    let kind: String = AppGroupConstants.widgetKind

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: MusicTimelineProvider()) { entry in
            MusicWidgetEntryView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Now Playing")
        .description("Shows the currently playing song with playback controls.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Views

struct MusicWidgetEntryView: View {
    @Environment(\.widgetFamily) var family
    var entry: MusicEntry

    var body: some View {
        switch family {
        case .systemSmall:
            smallView
        default:
            mediumView
        }
    }

    private var smallView: some View {
        ZStack {
            if let artImage {
                Image(nsImage: artImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .blur(radius: 20)
                    .overlay(Color.black.opacity(0.4))
            }

            VStack(spacing: 8) {
                if let artImage {
                    Image(nsImage: artImage)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 60, height: 60)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 4)
                } else {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(.quaternary)
                        .frame(width: 60, height: 60)
                        .overlay {
                            Image(systemName: "music.note")
                                .font(.title2)
                                .foregroundStyle(.secondary)
                        }
                }

                VStack(spacing: 2) {
                    Text(displayTitle)
                        .font(.caption.bold())
                        .lineLimit(1)
                    Text(entry.data.artist)
                        .font(.caption2)
                        .lineLimit(1)
                        .opacity(0.8)
                }

                Button(intent: PlayPauseIntent()) {
                    Image(systemName: entry.data.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
            .foregroundStyle(entry.albumArt != nil ? .white : .primary)
        }
    }

    private var mediumView: some View {
        HStack(spacing: 12) {
            if let artImage {
                Image(nsImage: artImage)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(radius: 4)
            } else {
                RoundedRectangle(cornerRadius: 10)
                    .fill(.quaternary)
                    .frame(width: 100, height: 100)
                    .overlay {
                        Image(systemName: "music.note")
                            .font(.largeTitle)
                            .foregroundStyle(.secondary)
                    }
            }

            VStack(alignment: .leading, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(displayTitle).font(.headline).lineLimit(1)
                    Text(entry.data.artist).font(.subheadline).foregroundStyle(.secondary).lineLimit(1)
                    Text(entry.data.album).font(.caption).foregroundStyle(.tertiary).lineLimit(1)
                }

                HStack(spacing: 24) {
                    Button(intent: PreviousTrackIntent()) {
                        Image(systemName: "backward.fill").font(.title2)
                    }
                    .buttonStyle(.plain)

                    Button(intent: PlayPauseIntent()) {
                        Image(systemName: entry.data.isPlaying ? "pause.fill" : "play.fill").font(.title)
                    }
                    .buttonStyle(.plain)

                    Button(intent: NextTrackIntent()) {
                        Image(systemName: "forward.fill").font(.title2)
                    }
                    .buttonStyle(.plain)
                }
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxHeight: .infinity)
        }
    }

    private var displayTitle: String {
        entry.data.title.isEmpty ? "Not Playing" : entry.data.title
    }

    private var artImage: NSImage? {
        guard let data = entry.albumArt else { return nil }
        return NSImage(data: data)
    }
}

// MARK: - Intents (write command files for the main app to execute)

struct PlayPauseIntent: AppIntent {
    static var title: LocalizedStringResource = "Play or Pause"
    static var description = IntentDescription("Toggles play/pause.")

    func perform() async throws -> some IntentResult {
        SharedDataStore.writeCommand("playpause")
        return .result()
    }
}

struct NextTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Next Track"
    static var description = IntentDescription("Skips to the next track.")

    func perform() async throws -> some IntentResult {
        SharedDataStore.writeCommand("next")
        return .result()
    }
}

struct PreviousTrackIntent: AppIntent {
    static var title: LocalizedStringResource = "Previous Track"
    static var description = IntentDescription("Goes back to the previous track.")

    func perform() async throws -> some IntentResult {
        SharedDataStore.writeCommand("previous")
        return .result()
    }
}
