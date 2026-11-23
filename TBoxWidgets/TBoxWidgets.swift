import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TBoxWidgetsBundle: WidgetBundle {
    var body: some Widget {
        DownloadLiveActivity()
    }
}

/// Avance de las descargas al iPhone en la Dynamic Island y la pantalla de bloqueo.
struct DownloadLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: DownloadActivityAttributes.self) { context in
            LockScreenDownloadView(state: context.state)
                .padding(16)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let s = context.state
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: s.finished ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text(Self.percent(s.progress))
                        .font(.title3.weight(.semibold))
                        .monospacedDigit()
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(s.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        ProgressView(value: s.progress)
                            .tint(.green)
                        Text(Self.detail(s))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                }
            } compactLeading: {
                Image(systemName: s.finished ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                    .foregroundStyle(.green)
            } compactTrailing: {
                Text(Self.percent(s.progress))
                    .font(.caption.weight(.semibold))
                    .monospacedDigit()
            } minimal: {
                Gauge(value: s.progress) {
                    Image(systemName: "arrow.down")
                }
                .gaugeStyle(.accessoryCircularCapacity)
                .tint(.green)
            }
        }
    }

    static func percent(_ p: Double) -> String {
        "\(Int((min(max(p, 0), 1) * 100).rounded()))%"
    }

    static func detail(_ s: DownloadActivityAttributes.ContentState) -> String {
        if s.finished { return String(localized: "Toca para abrir T-Box") }
        guard s.expected > 0 else { return String(localized: "Descargando en T-Box") }
        let got = ByteCountFormatter.string(fromByteCount: s.received, countStyle: .file)
        let total = ByteCountFormatter.string(fromByteCount: s.expected, countStyle: .file)
        return "\(got) / \(total)"
    }
}

struct LockScreenDownloadView: View {
    let state: DownloadActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: state.finished ? "checkmark.circle.fill" : "arrow.down.circle.fill")
                .font(.largeTitle)
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(state.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    Text(DownloadLiveActivity.percent(state.progress))
                        .font(.headline)
                        .monospacedDigit()
                }
                ProgressView(value: state.progress)
                    .tint(.green)
                Text(DownloadLiveActivity.detail(state))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
        }
        .foregroundStyle(.white)
    }
}
