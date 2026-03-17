# macMusicWidget

macOS Notification Center widget that displays currently playing Apple Music track info (title, artist, album, album art) with playback controls (play/pause, next, previous).

## Project Structure

```
MusicWidget/
├── MusicWidget/                  # Main app (unsandboxed menu bar app)
│   ├── MusicWidgetApp.swift      # Entry point, MenuBarExtra, launch-at-login toggle
│   ├── ContentView.swift         # Status window (unused in production)
│   ├── NowPlayingMonitor.swift   # Core engine: notifications, commands, artwork
│   └── Shared/                   # Shared types (also used by extension via membership)
│       ├── AppGroupConstants.swift
│       ├── NowPlayingData.swift
│       └── SharedDataStore.swift
├── MusicWidgetExtension/         # Widget extension (sandboxed)
│   ├── MusicWidgetExtension.swift      # Widget views (small/medium) + AppIntents
│   ├── MusicWidgetExtensionBundle.swift # @main entry
│   └── Info.plist
├── Shared/                       # Duplicate of shared files (extension target membership)
│   ├── AppGroupConstants.swift   # MUST be kept in sync with MusicWidget/Shared/
│   ├── NowPlayingData.swift
│   └── SharedDataStore.swift
└── macMusicWidget.xcodeproj
```

**Important:** Shared files exist in two places (`MusicWidget/Shared/` and `Shared/`). Both copies must be kept in sync manually — the app target uses the inner copy, the extension uses the outer copy.

## Architecture & Communication

The main app and widget extension cannot use App Groups (not available without paid Apple Developer enrollment). Instead:

### Track Info (Music → Main App → Widget)
- Main app observes `com.apple.Music.playerInfo` distributed notifications (no permissions needed)
- On launch, fetches current state via `osascript` (Process), falls back to last saved data
- Writes `NowPlayingData` JSON to the extension's sandbox container
- Path: `~/Library/Containers/com.macmusic.macMusic.MusicWidgetExtension/Data/Documents/MusicWidgetShared/nowplaying.json`

### Album Artwork (iTunes API → Main App → Widget)
- Main app searches the iTunes Search API (`itunes.apple.com/search`) by artist + album name
- Downloads artwork, resizes to 300px max, writes PNG to shared container
- Path: `.../MusicWidgetShared/albumart.png`

### Playback Controls (Widget → Main App → System)
- Widget extension AppIntents write command files (e.g., `playpause|<timestamp>`)
- Main app polls `command.txt` every 0.5 seconds
- On change, simulates media key press via CGEvent (NX_KEYTYPE_PLAY=16, NEXT=17, PREVIOUS=18)
- Path: `.../MusicWidgetShared/command.txt`

### Shared Container Path Resolution
- `AppGroupConstants.sharedContainerURL` detects sandbox via `APP_SANDBOX_CONTAINER_ID` env var
- Sandboxed (extension): `<containerHome>/Documents/MusicWidgetShared/`
- Unsandboxed (main app): `~/Library/Containers/<extensionBundleID>/Data/Documents/MusicWidgetShared/`
- Both resolve to the same physical directory

## Build Settings

- Main app: `ENABLE_APP_SANDBOX = NO` (needs to write to extension container, simulate media keys)
- Extension: `ENABLE_APP_SANDBOX = YES` (required for widget extensions)
- `MACOSX_DEPLOYMENT_TARGET = 15.7` (must match running OS, not SDK version)
- `INFOPLIST_KEY_LSUIElement = YES` (menu bar app, no dock icon)
- Bundle ID: `com.macmusic.macMusic` (app), `com.macmusic.macMusic.MusicWidgetExtension` (extension)

## What Does NOT Work (Permission Issues)

- **NSAppleScript** to control Music.app: returns -1743 "Not authorized" even with Automation enabled in System Settings. Code signature changes during Xcode rebuilds invalidate TCC grants. `tccutil reset` does not reliably fix it.
- **MediaRemote private framework**: returns "Operation not permitted" (error code 3).
- **DistributedNotificationCenter for sending commands from sandboxed extension**: unreliable, extension process may be killed before delivery.

## What Works Instead

- **Media key simulation** (CGEvent) for playback control — no permissions needed
- **iTunes Search API** for album artwork — no permissions needed
- **Distributed notifications for receiving** Music player state — no permissions needed
- **File-based IPC** through extension's sandbox container — no permissions needed
- **osascript via Process** for initial state fetch on launch — prompts for Automation once

## Building & Distribution

No paid Apple Developer enrollment, so no Archive/Distribute. Instead:
1. Set scheme build configuration to Release
2. Product → Build (Cmd+B)
3. Right-click MusicWidget.app in Products → Show in Finder
4. Copy to `/Applications`
5. Toggle "Launch at Login" from the menu bar icon
