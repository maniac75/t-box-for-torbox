import ActivityKit
import Combine
import Foundation

/// Muestra el avance de las descargas al iPhone en la Dynamic Island y en la pantalla de bloqueo.
/// Una sola Live Activity resume todas las descargas en curso.
@MainActor
final class LiveDownloads {
    static let shared = LiveDownloads()

    private var activity: Activity<DownloadActivityAttributes>?
    private var cancellable: AnyCancellable?
    private var lastSent: DownloadActivityAttributes.ContentState?
    private var lastSentAt = Date.distantPast
    /// Velocidad suavizada (bytes/s) para estimar el fin.
    private var speed: Double = 0

    func start() {
        guard cancellable == nil else { return }
        // Las que quedaron de una sesión anterior (app cerrada o reinstalada) se cierran:
        // su estimación ya no vale y no se deben ver dos a la vez.
        for old in Activity<DownloadActivityAttributes>.activities {
            Task { await old.end(nil, dismissalPolicy: .immediate) }
        }
        cancellable = DownloadManager.shared.$items
            .receive(on: RunLoop.main)
            .sink { [weak self] items in
                Task { @MainActor in self?.update(items) }
            }
    }

    private func update(_ items: [DownloadManager.Item]) {
        let running = items.filter { $0.status == .running }

        guard !running.isEmpty else {
            guard let current = activity else { return }
            let anyDone = items.contains { $0.status == .done || $0.status == .savedToPhotos }
            let total = lastSent?.expected ?? 0
            let final = DownloadActivityAttributes.ContentState(
                title: anyDone ? L("Descargas listas") : L("Descargas detenidas"),
                count: 0, progress: anyDone ? 1 : (lastSent?.progress ?? 0),
                received: anyDone ? total : (lastSent?.received ?? 0), expected: total, finished: true)
            activity = nil
            lastSent = nil
            speed = 0
            Task {
                await current.end(ActivityContent(state: final, staleDate: nil),
                                  dismissalPolicy: .after(Date.now.addingTimeInterval(15 * 60)))
            }
            return
        }

        let expected = running.reduce(Int64(0)) { $0 + max($1.expected, 0) }
        let received = running.reduce(Int64(0)) { $0 + max($1.received, 0) }
        let rawProgress = expected > 0
            ? Double(received) / Double(expected)
            : running.map(\.progress).reduce(0, +) / Double(running.count)
        var state = DownloadActivityAttributes.ContentState(
            title: running.count == 1 ? running[0].name : String(format: L("%d descargas"), running.count),
            count: running.count, progress: min(max(rawProgress, 0), 1),
            received: received, expected: expected, finished: false)

        speed = running.reduce(0) { $0 + $1.speed }
        state.speed = Int64(speed)
        let now = Date()
        // Solo se estima con una velocidad ya estable y un fin razonable (menos de 2 h);
        // si no, se muestra el porcentaje, que nunca engaña.
        if speed > 64 * 1024, expected > received, received > 4 * 1024 * 1024 {
            let remaining = Double(expected - received) / speed
            let elapsed = Double(received) / speed
            if remaining < 2 * 3600 {
                state.estimatedStart = now.addingTimeInterval(-elapsed)
                state.estimatedEnd = now.addingTimeInterval(remaining)
            }
        }

        if let current = activity {
            // iOS limita cuántas veces se puede actualizar: como mucho una vez por segundo,
            // y solo si cambió algo que se nota (1 % de avance, el número o el nombre).
            // Con estimación la barra avanza sola: basta corregirla cada ~15 s.
            let sameShape = state.count == lastSent?.count && state.title == lastSent?.title
                && (state.estimate == nil) == (lastSent?.estimate == nil)
            let smallStep = abs(state.progress - (lastSent?.progress ?? -1)) < 0.01
            let elapsed = Date().timeIntervalSince(lastSentAt)
            let minGap: TimeInterval = state.estimate != nil ? 15 : 10
            if sameShape && (elapsed < 1 || (smallStep && elapsed < 10) || (state.estimate != nil && elapsed < minGap)) { return }
            lastSent = state
            lastSentAt = Date()
            let stale = (state.estimatedEnd ?? Date.now).addingTimeInterval(10 * 60)
            Task { await current.update(ActivityContent(state: state, staleDate: stale)) }
        } else {
            guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
            do {
                activity = try Activity.request(attributes: DownloadActivityAttributes(),
                                                content: ActivityContent(state: state, staleDate: nil),
                                                pushType: nil)
                lastSent = state
                lastSentAt = Date()
            } catch {
                Diagnostics.log("LIVE activity failed: \(error.localizedDescription)")
            }
        }
    }
}
