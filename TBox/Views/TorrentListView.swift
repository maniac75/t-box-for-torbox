import SwiftUI

struct TorrentListView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case all = "Todos", active = "En curso", ready = "Listos"
        var id: String { rawValue }
    }

    let kind: ItemKind

    @EnvironmentObject private var state: AppState
    @State private var search = ""
    @State private var filter: Filter = .all
    @State private var toDelete: Torrent?

    private func matches(_ t: Torrent) -> Bool {
        let byFilter: Bool
        switch filter {
        case .all: byFilter = true
        case .active: byFilter = !t.isReady
        case .ready: byFilter = t.isReady
        }
        return byFilter && Self.matchesSearch(t, search)
    }

    /// Busca por nombre (sin distinguir mayúsculas ni acentos) o por hash.
    static func matchesSearch(_ t: Torrent, _ query: String) -> Bool {
        let q = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if q.isEmpty { return true }
        let opts: String.CompareOptions = [.caseInsensitive, .diacriticInsensitive, .widthInsensitive]
        if t.name.range(of: q, options: opts) != nil { return true }
        if let h = t.hash, h.range(of: q, options: .caseInsensitive) != nil { return true }
        return false
    }

    private var visible: [Torrent] {
        // Favoritos arriba, sin cambiar el orden dentro de cada grupo.
        let all = state.items(kind).filter(matches)
        return all.filter { state.isFavorite($0) } + all.filter { !state.isFavorite($0) }
    }

    var body: some View {
        NavigationStack {
            List {
                Picker("Filtro", selection: $filter) {
                    ForEach(Filter.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                }
                .pickerStyle(.segmented)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                if let err = state.errorMessage {
                    Label(err, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange).font(.footnote)
                }

                let queue = state.queued(kind)
                if !queue.isEmpty {
                    Section {
                        ForEach(queue) { q in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(q.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                                Text("En cola de TorBox: empieza cuando haya un cupo libre.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            .swipeActions {
                                Button(role: .destructive) {
                                    Task { await state.controlQueued(q, kind: kind, operation: "delete") }
                                } label: { Label("Eliminar", systemImage: "trash") }
                            }
                            .swipeActions(edge: .leading) {
                                Button {
                                    Task { await state.controlQueued(q, kind: kind, operation: "start") }
                                } label: { Label("Iniciar", systemImage: "play.fill") }
                                .tint(.green)
                            }
                        }
                    } header: {
                        Text(String(format: L("En cola (%d)"), queue.count))
                    } footer: {
                        Text("Desliza a la derecha para intentar iniciarla ahora, o a la izquierda para borrarla.")
                    }
                }

                ForEach(visible) { t in
                    NavigationLink(value: t.ref) { TorrentRow(torrent: t, favorite: state.isFavorite(t)) }
                        .swipeActions {
                            Button(role: .destructive) { toDelete = t } label: { Label("Eliminar", systemImage: "trash") }
                        }
                        .swipeActions(edge: .leading) {
                            Button { state.toggleFavorite(t) } label: {
                                Label(state.isFavorite(t) ? L("Quitar de favoritos") : L("Favorito"),
                                      systemImage: state.isFavorite(t) ? "star.slash" : "star.fill")
                            }
                            .tint(.yellow)
                            if t.isReady && state.user?.isFree != true {
                                Button {
                                    Task {
                                        if let e = await state.setAirlock(t, on: !t.airlocked) { state.errorMessage = e }
                                    }
                                } label: {
                                    Label(t.airlocked ? L("Quitar AirLock") : L("AirLock"),
                                          systemImage: t.airlocked ? "lock.open" : "lock.fill")
                                }
                                .tint(.indigo)
                            }
                        }
                }
            }
            .listStyle(.insetGrouped)
            .overlay {
                if state.items(kind).isEmpty && !state.isLoading {
                    ContentUnavailableView(kind == .torrent ? L("Sin torrents") : L("Sin descargas web"),
                                           systemImage: kind == .torrent ? "tray" : "link",
                                           description: Text(kind == .torrent
                                                             ? L("Toca + o abre un magnet desde Safari.")
                                                             : L("Toca + y pega un enlace de YouTube, Instagram, X, Mega u otro sitio.")))
                } else if !search.isEmpty && visible.isEmpty {
                    ContentUnavailableView.search(text: search)
                }
            }
            .navigationTitle(kind.title)
            .navigationDestination(for: ItemRef.self) { ref in TorrentDetailView(ref: ref) }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar por nombre o hash")
            .refreshable { await state.refresh() }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { state.openAdd() } label: { Image(systemName: "plus") }
                }
                ToolbarItem(placement: .topBarLeading) {
                    if state.isLoading { ProgressView() }
                }
            }
            .confirmationDialog("¿Eliminar de TorBox?",
                                isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }),
                                titleVisibility: .visible,
                                presenting: toDelete) { t in
                Button("Eliminar", role: .destructive) { Task { await state.delete(t) } }
            } message: { t in
                Text(t.name)
            }
            .task {
                await state.refresh()
                state.startPolling()
            }
        }
    }
}

struct TorrentRow: View {
    let torrent: Torrent
    var favorite = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if favorite {
                    Image(systemName: "star.fill").font(.caption).foregroundStyle(.yellow)
                        .accessibilityLabel(L("Favorito"))
                }
                Text(torrent.name)
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
            }
            if let err = torrent.errorText, !torrent.isReady {
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
        let failed = torrent.errorText != nil && !ready
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
