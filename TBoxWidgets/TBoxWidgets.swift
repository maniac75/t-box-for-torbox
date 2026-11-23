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
/// Mientras iOS tiene la app dormida no puede mandar el porcentaje, así que la barra
/// y el tiempo restante avanzan solos según la última velocidad medida.
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
                    StatusIcon(finished: s.finished).font(.title2)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    TrailingValue(state: s)
                        .font(.title3.weight(.semibold))
                        .frame(maxWidth: 76, alignment: .trailing)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(s.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        Bar(state: s)
                        DetailLine(state: s)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } compactLeading: {
                StatusIcon(finished: s.finished)
            } compactTrailing: {
                TrailingValue(state: s)
                    .font(.caption.weight(.semibold))
                    .frame(maxWidth: 44)
            } minimal: {
                if let range = s.estimate {
                    ProgressView(timerInterval: range, countsDown: false) {
                        EmptyView()
                    } currentValueLabel: {
                        Image(systemName: "arrow.down")
                    }
                    .progressViewStyle(.circular)
                    .tint(.green)
                } else {
                    Gauge(value: s.progress) {
                        Image(systemName: "arrow.down")
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(.green)
                }
            }
        }
    }
}

struct StatusIcon: View {
    let finished: Bool
    var body: some View {
        Image(systemName: finished ? "checkmark.circle.fill" : "arrow.down.circle.fill")
            .foregroundStyle(.green)
    }
}

/// Tiempo restante (cuenta regresiva) si hay estimación; si no, el porcentaje.
struct TrailingValue: View {
    let state: DownloadActivityAttributes.ContentState
    var body: some View {
        Group {
            if let range = state.estimate {
                Text(timerInterval: Date.now...max(range.upperBound, Date.now), countsDown: true, showsHours: false)
                    .multilineTextAlignment(.trailing)
            } else {
                Text(DownloadLiveActivity.percent(state.finished ? 1 : state.progress))
            }
        }
        .monospacedDigit()
        .lineLimit(1)
        .minimumScaleFactor(0.6)
    }
}

struct Bar: View {
    let state: DownloadActivityAttributes.ContentState
    var body: some View {
        Group {
            if let range = state.estimate {
                ProgressView(timerInterval: range, countsDown: false) { EmptyView() } currentValueLabel: { EmptyView() }
            } else {
                ProgressView(value: state.finished ? 1 : state.progress)
            }
        }
        .tint(.green)
    }
}

struct DetailLine: View {
    let state: DownloadActivityAttributes.ContentState
    var body: some View {
        Group {
            if state.finished {
                Text("Toca para abrir T-Box")
            } else if state.expected > 0, state.estimate != nil {
                // Los bytes no se pueden actualizar con la app dormida: total y velocidad.
                Text("\(ByteCountFormatter.string(fromByteCount: state.expected, countStyle: .file)) · \(ByteCountFormatter.string(fromByteCount: state.speed, countStyle: .file))/s")
            } else if state.expected > 0 {
                Text("\(ByteCountFormatter.string(fromByteCount: state.received, countStyle: .file)) / \(ByteCountFormatter.string(fromByteCount: state.expected, countStyle: .file))")
            } else {
                Text("Descargando en T-Box")
            }
        }
        .monospacedDigit()
        .lineLimit(1)
    }
}

extension DownloadLiveActivity {
    static func percent(_ p: Double) -> String {
        "\(Int((min(max(p, 0), 1) * 100).rounded()))%"
    }
}

struct LockScreenDownloadView: View {
    let state: DownloadActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 14) {
            StatusIcon(finished: state.finished).font(.largeTitle)
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(state.title)
                        .font(.headline)
                        .lineLimit(1)
                    Spacer()
                    TrailingValue(state: state)
                        .font(.headline)
                        .frame(maxWidth: 76, alignment: .trailing)
                }
                Bar(state: state)
                DetailLine(state: state)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .foregroundStyle(.white)
    }
}
