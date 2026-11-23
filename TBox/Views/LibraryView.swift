import SwiftUI

/// Biblioteca única: torrents y descargas web juntos, con filtros, orden y selección múltiple.
struct LibraryView: View {
    enum Scope: String, CaseIterable, Identifiable {
        case all = "Todo", torrent = "Torrents", web = "Web"
        var id: String { rawValue }
    }

    enum Filter: String, CaseIterable, Identifiable {
        case all = "Todos", active = "En curso", ready = "Listos", favorites = "Favoritos"
        var id: String { rawValue }
        var icon: String {
            switch self {
            case .all: return "tray.full"
            case .active: return "arrow.down.circle"
            case .ready: return "checkmark.circle"
            case .favorites: return "star"
            }
        }
    }

    enum Sort: String, CaseIterable, Identifiable {
        case newest = "Más nuevos", oldest = "Más antiguos", name = "Nombre", size = "Tamaño"
        var id: String { rawValue }
    }

    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var downloads: DownloadManager

    @AppStorage("library.scope") private var scope: Scope = .all
    @AppStorage("library.filter") private var filter: Filter = .all
    @AppStorage("library.sort") private var sort: Sort = .newest

    @State private var search = ""
    @State private var toDelete: Torrent?
    @State private var selecting = false
    @State private var selection = Set<ItemRef>()
    @State private var confirmBulkDelete = false
    @State private var working = false
    @State private var notice: String?

    // MARK: Datos

    private var source: [Torrent] {
        switch scope {
        case .all: return state.torrents + state.webDownloads
        case .torrent: return state.torrents
        case .web: return state.webDownloads
        }
    }

    private func passesFilter(_ t: Torrent) -> Bool {
        switch filter {
        case .all: return true
        case .active: return !t.isReady
        case .ready: return t.isReady
        case .favorites: return state.isFavorite(t)
        }
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

    private func sorted(_ list: [Torrent]) -> [Torrent] {
        switch sort {
        case .newest: return list.sorted { ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast) }
        case .oldest: return list.sorted { ($0.createdDate ?? .distantFuture) < ($1.createdDate ?? .distantFuture) }
        case .name: return list.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        case .size: return list.sorted { $0.size > $1.size }
        }
    }

    private var visible: [Torrent] {
        // Favoritos arriba, respetando el orden elegido dentro de cada grupo.
        let all = sorted(source.filter { passesFilter($0) && Self.matchesSearch($0, search) })
        return all.filter { state.isFavorite($0) } + all.filter { !state.isFavorite($0) }
    }

    private struct QueueEntry: Identifiable {
        let kind: ItemKind
        let item: QueuedItem
        var id: String { "\(kind.rawValue)-\(item.id)" }
    }

    private var queue: [QueueEntry] {
        let t = scope == .web ? [] : state.queuedTorrents.map { QueueEntry(kind: .torrent, item: $0) }
        let w = scope == .torrent ? [] : state.queuedWeb.map { QueueEntry(kind: .web, item: $0) }
        return t + w
    }

    private var selectedItems: [Torrent] { visible.filter { selection.contains($0.ref) } }
    private var selectedReady: [Torrent] { selectedItems.filter(\.isReady) }
    private var canAirlock: Bool { state.user?.isFree != true }

    private var title: String {
        if selecting {
            return selection.isEmpty ? L("Seleccionar") : String(format: L("%d seleccionados"), selection.count)
        }
        return L("Biblioteca")
    }

    // MARK: Vista

    var body: some View {
        NavigationStack {
            List(selection: selecting ? $selection : nil) {
                if !selecting {
                    Picker("Tipo", selection: $scope) {
                        ForEach(Scope.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 4, trailing: 0))

                    if filter != .all {
                        Button { filter = .all } label: {
                            Label(String(format: L("Mostrando: %@ · Ver todos"), L(filter.rawValue)),
                                  systemImage: "line.3.horizontal.decrease.circle.fill")
                                .font(.footnote)
                        }
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 4, bottom: 0, trailing: 0))
                    }
                }

                if let err = state.errorMessage {
                    Label(err, systemImage: "exclamationmark.triangle")
                        .foregroundStyle(.orange).font(.footnote)
                }

                if !queue.isEmpty && !selecting && filter != .ready && filter != .favorites {
                    queueSection
                }

                ForEach(visible, id: \.ref) { t in
                    row(t)
                }
            }
            .listStyle(.insetGrouped)
            .environment(\.editMode, .constant(selecting ? .active : .inactive))
            .overlay { emptyState }
            .overlay(alignment: .top) {
                if let notice {
                    Text(notice)
                        .font(.footnote.weight(.semibold))
                        .padding(.horizontal, 14).padding(.vertical, 8)
                        .background(.thinMaterial, in: Capsule())
                        .padding(.top, 6)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .safeAreaInset(edge: .bottom) {
                if selecting { bulkBar } else { ActivityBar() }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(selecting ? .inline : .large)
            .navigationDestination(for: ItemRef.self) { ref in TorrentDetailView(ref: ref) }
            .searchable(text: $search, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar por nombre o hash")
            .refreshable { await state.refresh() }
            .toolbar { toolbar }
            .confirmationDialog("¿Eliminar de TorBox?",
                                isPresented: Binding(get: { toDelete != nil }, set: { if !$0 { toDelete = nil } }),
                                titleVisibility: .visible,
                                presenting: toDelete) { t in
                Button("Eliminar", role: .destructive) { Task { await state.delete(t) } }
            } message: { t in
                Text(t.name)
            }
            .confirmationDialog(String(format: L("¿Eliminar %d de TorBox?"), selection.count),
                                isPresented: $confirmBulkDelete,
                                titleVisibility: .visible) {
                Button(String(format: L("Eliminar %d"), selection.count), role: .destructive) {
                    let items = selectedItems
                    Task {
                        working = true
                        let failed = await state.deleteMany(items)
                        working = false
                        endSelection()
                        flash(failed == 0 ? String(format: L("%d eliminados"), items.count)
                                          : String(format: L("%d no se pudieron eliminar"), failed))
                    }
                }
            } message: {
                Text("Se borran de tu cuenta de TorBox. Lo que ya bajaste al iPhone no se toca.")
            }
            .onChange(of: visible.map(\.ref)) { _, refs in
                // Si algo seleccionado desaparece (otro filtro, se borró), deja de contar.
                selection.formIntersection(refs)
            }
            .task {
                await state.refresh()
                state.startPolling()
            }
        }
    }

    @ViewBuilder
    private func row(_ t: Torrent) -> some View {
        let favorite = state.isFavorite(t)
        let content = TorrentRow(torrent: t, favorite: favorite, showKind: scope == .all)
        Group {
            if selecting {
                content
            } else {
                NavigationLink(value: t.ref) { content }
            }
        }
        .swipeActions {
            if !selecting {
                Button(role: .destructive) { toDelete = t } label: { Label("Eliminar", systemImage: "trash") }
            }
        }
        .swipeActions(edge: .leading) {
            if !selecting {
                Button { state.toggleFavorite(t) } label: {
                    Label(favorite ? L("Quitar de favoritos") : L("Favorito"),
                          systemImage: favorite ? "star.slash" : "star.fill")
                }
                .tint(.yellow)
                if t.isReady && canAirlock {
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
        .contextMenu {
            if !selecting {
                Button { state.toggleFavorite(t) } label: {
                    Label(favorite ? L("Quitar de favoritos") : L("Favorito"),
                          systemImage: favorite ? "star.slash" : "star")
                }
                Button {
                    selection = [t.ref]
                    withAnimation { selecting = true }
                } label: { Label("Seleccionar", systemImage: "checkmark.circle") }
                Divider()
                Button(role: .destructive) { toDelete = t } label: { Label("Eliminar", systemImage: "trash") }
            }
        }
    }

    private var queueSection: some View {
        Section {
            ForEach(queue) { q in
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        if scope == .all { KindIcon(kind: q.kind) }
                        Text(q.item.name).font(.subheadline.weight(.semibold)).lineLimit(2)
                    }
                    Text("En cola de TorBox: empieza cuando haya un cupo libre.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .swipeActions {
                    Button(role: .destructive) {
                        Task { await state.controlQueued(q.item, kind: q.kind, operation: "delete") }
                    } label: { Label("Eliminar", systemImage: "trash") }
                }
                .swipeActions(edge: .leading) {
                    Button {
                        Task { await state.controlQueued(q.item, kind: q.kind, operation: "start") }
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

    @ViewBuilder
    private var emptyState: some View {
        if source.isEmpty && queue.isEmpty && !state.isLoading {
            ContentUnavailableView(L("Tu biblioteca está vacía"),
                                   systemImage: "books.vertical",
                                   description: Text("Toca + para agregar un magnet, un archivo .torrent o un enlace web."))
        } else if !search.isEmpty && visible.isEmpty {
            ContentUnavailableView.search(text: search)
        } else if visible.isEmpty && queue.isEmpty && !state.isLoading {
            ContentUnavailableView(L("Nada por aquí"),
                                   systemImage: filter.icon,
                                   description: Text("Ningún elemento coincide con este filtro."))
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        if selecting {
            ToolbarItem(placement: .topBarLeading) {
                let all = Set(visible.map(\.ref))
                Button(selection == all && !all.isEmpty ? L("Ninguno") : L("Todos")) {
                    selection = selection == all ? [] : all
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                Button("Listo") { endSelection() }.bold()
            }
        } else {
            ToolbarItem(placement: .topBarLeading) {
                if state.isLoading { ProgressView() }
            }
            ToolbarItemGroup(placement: .topBarTrailing) {
                Menu {
                    Picker("Mostrar", selection: $filter) {
                        ForEach(Filter.allCases) { f in
                            Label(LocalizedStringKey(f.rawValue), systemImage: f.icon).tag(f)
                        }
                    }
                    Picker("Ordenar", selection: $sort) {
                        ForEach(Sort.allCases) { Text(LocalizedStringKey($0.rawValue)).tag($0) }
                    }
                    Divider()
                    Button { withAnimation { selecting = true } } label: {
                        Label("Seleccionar", systemImage: "checkmark.circle")
                    }
                    .disabled(visible.isEmpty)
                } label: {
                    Image(systemName: filter == .all
                          ? "line.3.horizontal.decrease.circle"
                          : "line.3.horizontal.decrease.circle.fill")
                }
                .accessibilityLabel(L("Filtrar y ordenar"))
                Button { state.openAdd() } label: { Image(systemName: "plus") }
                    .accessibilityLabel(L("Agregar"))
            }
        }
    }

    // MARK: Acciones en lote

    private var bulkBar: some View {
        let items = selectedItems
        let ready = selectedReady
        let allFavorite = !items.isEmpty && items.allSatisfy { state.isFavorite($0) }
        let allLocked = !ready.isEmpty && ready.allSatisfy(\.airlocked)
        return HStack(spacing: 0) {
            bulkButton(allFavorite ? L("Quitar") : L("Favorito"),
                       icon: allFavorite ? "star.slash" : "star.fill",
                       enabled: !items.isEmpty) {
                state.setFavorite(items, !allFavorite)
                flash(allFavorite ? L("Quitados de favoritos") : L("Marcados como favoritos"))
            }
            if canAirlock {
                bulkButton(allLocked ? L("Quitar AirLock") : L("AirLock"),
                           icon: allLocked ? "lock.open" : "lock.fill",
                           enabled: !ready.isEmpty) {
                    Task {
                        working = true
                        let failed = await state.airlockMany(ready, on: !allLocked)
                        working = false
                        flash(failed == 0 ? (allLocked ? L("AirLock quitado") : L("AirLock activado"))
                                          : String(format: L("%d no se pudieron cambiar"), failed))
                    }
                }
            }
            bulkButton(L("Al iPhone"), icon: "iphone.and.arrow.forward", enabled: !ready.isEmpty) {
                Task { await downloadToPhone(ready) }
            }
            bulkButton(L("Eliminar"), icon: "trash", enabled: !items.isEmpty, destructive: true) {
                confirmBulkDelete = true
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 6)
        .background(.bar)
        .overlay(alignment: .top) { Divider() }
        .overlay { if working { ProgressView().controlSize(.large) } }
        .disabled(working)
    }

    private func bulkButton(_ title: String, icon: String, enabled: Bool, destructive: Bool = false,
                            action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon).font(.title3)
                Text(title).font(.caption2).lineLimit(1).minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(destructive ? Color.red : Color.accentColor)
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
        .opacity(enabled ? 1 : 0.35)
    }

    /// Un archivo se baja tal cual; si tiene varios, como .zip.
    private func downloadToPhone(_ items: [Torrent]) async {
        working = true
        var started = 0
        var lastError: String?
        for t in items {
            do {
                if t.files.count == 1, let f = t.files.first {
                    let url = try await state.api.downloadLink(t.kind, id: t.id, fileID: f.id)
                    downloads.start(url: url, filename: f.displayName)
                } else {
                    let url = try await state.api.downloadLink(t.kind, id: t.id, fileID: nil, zip: true)
                    downloads.start(url: url, filename: t.name + ".zip")
                }
                started += 1
            } catch {
                lastError = error.localizedDescription
            }
        }
        working = false
        endSelection()
        if let lastError, started == 0 {
            flash(lastError)
        } else {
            flash(String(format: L("%d descargas iniciadas"), started))
        }
    }

    private func endSelection() {
        withAnimation {
            selecting = false
            selection.removeAll()
        }
    }

    private func flash(_ text: String) {
        withAnimation { notice = text }
        Task {
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            withAnimation { if notice == text { notice = nil } }
        }
    }
}

/// Ícono chico que distingue un torrent de una descarga web en la vista "Todo".
struct KindIcon: View {
    let kind: ItemKind
    var body: some View {
        Image(systemName: kind == .torrent ? "arrow.down.doc" : "link")
            .font(.caption2.weight(.semibold))
            .foregroundStyle(.secondary)
            .accessibilityLabel(kind == .torrent ? L("Torrent") : L("Descarga web"))
    }
}
