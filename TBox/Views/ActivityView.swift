import SwiftUI

/// Barra flotante sobre las pestañas: solo aparece cuando hay algo en curso.
struct ActivityBar: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var downloads: DownloadManager
    @State private var showSheet = false

    private var running: [DownloadManager.Item] { downloads.items.filter { $0.isActive } }
    private var allPaused: Bool { !running.isEmpty && running.allSatisfy { $0.status == .paused } }

    private var phoneProgress: Double? {
        let r = running.filter { $0.expected > 0 }
        guard !r.isEmpty else { return nil }
        let total = r.reduce(Int64(0)) { $0 + $1.expected }
        let got = r.reduce(Int64(0)) { $0 + $1.received }
        return total > 0 ? Double(got) / Double(total) : nil
    }

    var body: some View {
        let torbox = state.activeInTorBox.count
        if torbox > 0 || !running.isEmpty {
            Button { showSheet = true } label: {
                HStack(spacing: 10) {
                    if allPaused {
                        Image(systemName: "pause.circle.fill").foregroundStyle(.secondary)
                    } else {
                        ProgressView().controlSize(.small)
                    }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(summary(torbox: torbox)).font(.footnote.weight(.semibold)).lineLimit(1)
                        if let p = phoneProgress {
                            ProgressView(value: p).tint(.green)
                        }
                    }
                    Spacer()
                    Image(systemName: "chevron.up").font(.caption.weight(.bold)).foregroundStyle(.secondary)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal, 12)
                .padding(.bottom, 4)
            }
            .buttonStyle(.plain)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .sheet(isPresented: $showSheet) { ActivitySheet().presentationDetents([.medium, .large]) }
        }
    }

    private func summary(torbox: Int) -> String {
        var parts: [String] = []
        if torbox > 0 { parts.append(String(format: L("%d en TorBox"), torbox)) }
        if !running.isEmpty {
            var s = String(format: L("%d al iPhone"), running.count)
            if let p = phoneProgress { s += " \(Int(p * 100))%" }
            if allPaused { s += " · " + L("en pausa") }
            parts.append(s)
        }
        return parts.joined(separator: " · ")
    }
}

/// Panel con todo lo que está pasando: en TorBox, bajando al iPhone y terminado hace poco.
struct ActivitySheet: View {
    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var downloads: DownloadManager
    @Environment(\.dismiss) private var dismiss
    @State private var toDelete: Torrent?
    @State private var confirmDeleteStalled = false
    @State private var confirmCancelAll = false

    private var stalled: [Torrent] {
        state.activeInTorBox.filter { $0.downloadState.lowercased().hasPrefix("stalled") || ($0.downloadSpeed == 0 && $0.progress == 0) }
    }

    var body: some View {
        NavigationStack {
            List {
                let torbox = state.activeInTorBox
                if !torbox.isEmpty {
                    Section {
                        ForEach(torbox) { t in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(t.name).font(.subheadline).lineLimit(2)
                                ProgressView(value: min(max(t.progress, 0), 1))
                                HStack {
                                    Text(Fmt.state(t.downloadState) + " · \(Int(t.progress * 100))%")
                                    if t.downloadSpeed > 0 { Text("↓ " + Fmt.speed(t.downloadSpeed)) }
                                    if let eta = Fmt.eta(t.eta) { Text("· " + eta) }
                                }
                                .font(.caption).foregroundStyle(.secondary)
                            }
                            .swipeActions {
                                Button(role: .destructive) { toDelete = t } label: {
                                    Label("Eliminar", systemImage: "trash")
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("En TorBox")
                            Spacer()
                            if !stalled.isEmpty {
                                Button(String(format: L("Eliminar detenidos (%d)"), stalled.count)) { confirmDeleteStalled = true }
                                    .font(.caption)
                            }
                        }
                    } footer: {
                        Text("Desliza a la izquierda para eliminar de TorBox lo que no avanza.")
                    }
                }
                let running = downloads.items.filter { $0.isActive }
                if !running.isEmpty {
                    Section {
                        ForEach(running) { item in
                            HStack(spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(item.name).font(.subheadline).lineLimit(2)
                                    ProgressView(value: item.progress).tint(item.status == .paused ? .gray : .green)
                                    Text(item.detailText)
                                        .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                                }
                                PauseButton(item: item)
                            }
                            .swipeActions {
                                Button(role: .destructive) { downloads.cancel(item) } label: {
                                    Label("Cancelar", systemImage: "stop.circle")
                                }
                            }
                        }
                    } header: {
                        HStack {
                            Text("Bajando al iPhone")
                            Spacer()
                            if downloads.canPauseAll {
                                Button("Pausar todas") { downloads.pauseAll() }.font(.caption)
                            } else {
                                Button("Reanudar todas") { downloads.resumeAll() }.font(.caption)
                            }
                            Button("Cancelar todas") { confirmCancelAll = true }.font(.caption)
                        }
                    } footer: {
                        if AppSettings.wifiOnly {
                            Text("Solo con wifi: sin wifi, las descargas esperan hasta que vuelva.")
                        }
                    }
                }
                let done = downloads.items.filter { !$0.isActive }
                if !done.isEmpty {
                    Section {
                        ForEach(done) { item in
                            DownloadStatusRow(item: item)
                        }
                    } header: {
                        HStack {
                            Text("Terminado hace poco")
                            Spacer()
                            Button("Limpiar") { downloads.clearFinished() }.font(.caption)
                        }
                    }
                }
                if torbox.isEmpty && running.isEmpty && done.isEmpty {
                    Text("No hay nada en curso.").foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Actividad")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Cerrar") { dismiss() } } }
            .refreshable { await state.refresh() }
            .confirmationDialog("¿Eliminar de TorBox?",
                                isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }),
                                titleVisibility: .visible, presenting: toDelete) { t in
                Button("Eliminar", role: .destructive) { Task { await state.delete(t) } }
            } message: { t in Text(t.name) }
            .confirmationDialog(String(format: L("¿Eliminar de TorBox %d descargas detenidas?"), stalled.count),
                                isPresented: $confirmDeleteStalled, titleVisibility: .visible) {
                Button("Eliminar", role: .destructive) {
                    let list = stalled
                    Task { for t in list { await state.delete(t) } }
                }
            } message: {
                Text("Son las que no tienen seeds o no han avanzado nada. Se borran de tu cuenta de TorBox.")
            }
            .confirmationDialog("¿Cancelar todas las descargas al iPhone?", isPresented: $confirmCancelAll,
                                titleVisibility: .visible) {
                Button("Cancelar todas", role: .destructive) { downloads.cancelAll() }
            }
        }
    }
}

struct DownloadStatusRow: View {
    let item: DownloadManager.Item

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.name).font(.subheadline).lineLimit(2)
            switch item.status {
            case .running, .paused:
                ProgressView(value: item.progress).tint(item.status == .paused ? .gray : .green)
                Text(item.detailText)
                    .font(.caption).foregroundStyle(.secondary).monospacedDigit()
            case .done:
                Label(item.savedTo.map { L("Guardado en ") + $0 } ?? L("Completada"),
                      systemImage: "checkmark.circle.fill")
                    .font(.caption).foregroundStyle(.green)
            case .savedToPhotos:
                Label("Guardada en Fotos", systemImage: "photo.badge.checkmark")
                    .font(.caption).foregroundStyle(.green)
            case .failed(let msg):
                Label(msg, systemImage: "xmark.octagon.fill").font(.caption).foregroundStyle(.red)
            }
        }
    }
}

/// Botón redondo de pausa / reanudar para una descarga al iPhone.
struct PauseButton: View {
    let item: DownloadManager.Item
    @EnvironmentObject private var downloads: DownloadManager

    var body: some View {
        let paused = item.status == .paused
        Button {
            if paused { downloads.resume(item) } else { downloads.pause(item) }
        } label: {
            Image(systemName: paused ? "play.circle.fill" : "pause.circle.fill")
                .font(.title2)
                .foregroundStyle(paused ? Color.green : Color.secondary)
                .frame(width: 44, height: 44)
        }
        .buttonStyle(.borderless)
        .accessibilityLabel(paused ? L("Reanudar") : L("Pausar"))
    }
}

/// Aviso breve arriba de la pantalla ("Listo: …").
struct ToastView: View {
    @ObservedObject var toaster = Toaster.shared

    var body: some View {
        if let t = toaster.current {
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text(t.title).font(.footnote.weight(.semibold))
                    if let d = t.detail { Text(d).font(.caption).foregroundStyle(.secondary).lineLimit(2) }
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            .padding(.horizontal, 16)
            .padding(.top, 6)
            .transition(.move(edge: .top).combined(with: .opacity))
            .onTapGesture { withAnimation { toaster.current = nil } }
            .id(t.id)
        }
    }
}

extension View {
    /// Agrega la barra de actividad sobre la barra de pestañas.
    func withActivityBar() -> some View {
        safeAreaInset(edge: .bottom) { ActivityBar() }
    }
}
