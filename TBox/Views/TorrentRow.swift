import SwiftUI

struct TorrentRow: View {
    let torrent: Torrent
    var favorite = false
    var showKind = false
    @AppStorage("library.cleanTitles") private var cleanTitles = true

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if showKind { KindIcon(kind: torrent.kind) }
                if favorite {
                    Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow)
                        .accessibilityLabel(L("Favorito"))
                }
                Text(cleanTitles ? CleanTitle.cached(torrent.name) : torrent.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
            }
            if let err = torrent.failureText, !torrent.isReady {
                Text(err).font(.caption).foregroundStyle(.red).lineLimit(2)
            } else if !torrent.isReady {
                ProgressView(value: min(max(torrent.progress, 0), 1))
            }
            HStack(spacing: 8) {
                StateBadge(torrent: torrent)
                Text(Fmt.bytes(torrent.size))
                if !torrent.isReady {
                    if torrent.downloadSpeed > 0 { Text("↓ " + Fmt.speed(torrent.downloadSpeed)) }
                    if let eta = Fmt.eta(torrent.eta) { Text("· " + eta) }
                }
                Spacer()
                if torrent.airlocked {
                    Image(systemName: "lock.fill").foregroundStyle(.indigo)
                        .accessibilityLabel(L("En AirLock"))
                }
                if torrent.isReady && torrent.files.count > 1 {
                    Text(String(format: L("%d archivos"), torrent.files.count))
                }
            }
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }
}

struct StateBadge: View {
    let torrent: Torrent

    var body: some View {
        let ready = torrent.isReady
        let failed = torrent.failureText != nil && !ready
        let stalled = torrent.downloadState.lowercased().hasPrefix("stalled")
        let color: Color = ready ? .green : (failed ? .red : (stalled ? .orange : .blue))
        Text(ready ? L("Listo") : (failed ? L("Error") : Fmt.state(torrent.downloadState) + " \(Int(torrent.progress * 100))%"))
            .font(.caption2.weight(.bold))
            .lineLimit(1)
            .fixedSize()
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(color.opacity(0.18), in: Capsule())
            .foregroundStyle(color)
    }
}
