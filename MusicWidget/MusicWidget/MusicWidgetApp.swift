import SwiftUI
import ServiceManagement

@main
struct MusicWidgetApp: App {
    @StateObject private var monitor = NowPlayingMonitor()
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some Scene {
        MenuBarExtra("macMusic", systemImage: "music.note") {
            VStack(spacing: 8) {
                if monitor.currentData.title != "Not Playing",
                   !monitor.currentData.title.isEmpty {
                    Text(monitor.currentData.title).font(.headline)
                    Text(monitor.currentData.artist).foregroundStyle(.secondary)
                    Divider()
                }

                HStack(spacing: 8) {
                    Circle()
                        .fill(monitor.isActive ? .green : .red)
                        .frame(width: 6, height: 6)
                    Text(monitor.isActive ? "Monitoring" : "Inactive")
                }

                Divider()

                Toggle("Launch at Login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        setLaunchAtLogin(newValue)
                    }

                Divider()
                Button("Quit") {
                    NSApplication.shared.terminate(nil)
                }
                .keyboardShortcut("q")
            }
            .padding(8)
        }
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Launch at login error: \(error)")
        }
    }
}
