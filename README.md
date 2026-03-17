# macMusicWidget

A lightweight macOS Notification Center widget that displays currently playing song information from Apple Music with playback controls.

![macOS](https://img.shields.io/badge/macOS-15.0%2B-blue)
![Swift](https://img.shields.io/badge/Swift-6.0%2B-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## Features

- **Now Playing info** — title, artist, album, and album artwork in your Notification Center
- **Playback controls** — play/pause, next track, and previous track directly from the widget
- **Two widget sizes** — compact (small) and detailed (medium) layouts
- **Menu bar app** — runs silently in the menu bar with no dock icon
- **Launch at login** — optional toggle to start automatically on boot
- **No paid Apple Developer account required** — build and run with a free personal team

## Screenshots

| Small Widget | Medium Widget |
|---|---|
| Album art background with title, artist, and play/pause | Full album art, track details, and prev/play/next controls |

## Requirements

- macOS 15.0 (Sequoia) or later
- Xcode 16 or later
- Apple Music app (comes pre-installed on macOS)

## Permissions

macMusicWidget requires **no special permissions or entitlements**. It avoids AppleScript Automation and private frameworks entirely:

| Feature | How It Works | Permissions |
|---|---|---|
| Track info | Listens to `com.apple.Music.playerInfo` distributed notifications | None |
| Album artwork | Fetches from the public iTunes Search API | None (network access) |
| Playback controls | Simulates media key presses via CGEvent | None |

On first launch, `osascript` may request Automation permission for Apple Music to fetch the currently playing track. This is optional — if denied, the app will pick up track info on the next play/pause or track change.

## Building

1. Clone the repository:
   ```bash
   git clone https://github.com/abreviks/macMusicWidget.git
   cd macMusicWidget
   ```

2. Set up local signing configuration:
   ```bash
   cp MusicWidget/Local.xcconfig.template MusicWidget/Local.xcconfig
   ```
   Edit `MusicWidget/Local.xcconfig` and set your `DEVELOPMENT_TEAM` ID (find it in Xcode under **Settings → Accounts**, or leave blank to set it manually in Xcode).

3. Open the Xcode project:
   ```bash
   open MusicWidget/macMusicWidget.xcodeproj
   ```

4. In Xcode, select the **MusicWidget** scheme and set the destination to **My Mac**

5. Build and run (Cmd+R)

### Installing Without a Paid Developer Account

You do not need a paid Apple Developer Program enrollment to build, install, or distribute this app:

1. In Xcode, go to **Product → Scheme → Edit Scheme → Run** and set **Build Configuration** to **Release**
2. Build the project (Cmd+B)
3. In the Project Navigator, expand **Products**, right-click **MusicWidget.app**, and select **Show in Finder**
4. Copy `MusicWidget.app` to `/Applications`
5. Launch from `/Applications` or Spotlight

To start automatically on boot, click the music note icon in the menu bar and toggle **Launch at Login**.

## Architecture

The app consists of two targets:

- **MusicWidget** — an unsandboxed menu bar app that monitors Apple Music and relays data
- **MusicWidgetExtension** — a sandboxed WidgetKit extension that displays the widget

Since App Groups require a paid developer account, the two targets communicate through the widget extension's sandbox container via shared files:

```
~/Library/Containers/<extension-bundle-id>/Data/Documents/MusicWidgetShared/
├── nowplaying.json   # Track metadata (written by main app, read by extension)
├── albumart.png      # Album artwork (written by main app, read by extension)
└── command.txt       # Playback commands (written by extension, polled by main app)
```

## How It Works

1. The main app listens for `com.apple.Music.playerInfo` distributed notifications to get track metadata
2. When a track changes, it writes the metadata to a shared JSON file and fetches album artwork from the iTunes Search API
3. The widget extension reads these files via a timeline provider that refreshes every 30 seconds
4. When a user taps a control button in the widget, the extension writes a command file
5. The main app polls for command file changes every 0.5 seconds and simulates the corresponding media key press

## License

MIT
