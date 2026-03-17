import SwiftUI

struct ContentView: View {
    @EnvironmentObject var monitor: NowPlayingMonitor

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "music.note")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)

            Text("Music Widget")
                .font(.title2.bold())

            HStack(spacing: 8) {
                Circle()
                    .fill(monitor.isActive ? .green : .red)
                    .frame(width: 8, height: 8)
                Text(monitor.isActive ? "Monitoring Apple Music" : "Not monitoring")
                    .foregroundStyle(.secondary)
            }

            if !monitor.currentData.title.isEmpty,
               monitor.currentData.title != "Not Playing" {
                GroupBox {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(monitor.currentData.title).font(.headline)
                        Text(monitor.currentData.artist).foregroundStyle(.secondary)
                        Text(monitor.currentData.album).foregroundStyle(.tertiary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }

            Spacer()

            Text("Add the Music Widget from\nNotification Center to get started.")
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(24)
        .frame(width: 300, height: 280)
    }
}
