import SwiftUI
import UniformTypeIdentifiers

/// Hoja única para agregar: magnets, enlaces web y archivos .torrent en un solo lugar.
/// Cada línea se reconoce sola y va a donde corresponde (Torrents o Web).
struct AddView: View {
    let initialText: String?
    let initialFile: URL?

    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var downloads: DownloadManager
    @Environment(\.dismiss) private var dismiss

    @State private var text = ""
    @State private var files: [URL] = []
    @State private var password = ""
    @State private var onlyCached = false
    @State private var showImporter = false
    @State private var sending = false
    @State private var hosters: [Hoster] = []
    @State private var entries: [AddEntry] = []
    @FocusState private var editorFocused: Bool

    private static let torrentType = UTType(filenameExtension: "torrent") ?? .data

    private var parsed: (links: [ParsedLink], ignored: [String]) { LinkParser.parse(text) }
    private var pendingCount: Int { parsed.links.count + files.count }
    private var hasWeb: Bool { parsed.links.contains { $0.kind == .web } }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    ZStack(alignment: .topTrailing) {
                        TextField("Magnet o enlace (YouTube, Instagram, Mega…)", text: $text, axis: .vertical)
                            .lineLimit(3...8)
                            .font(.footnote.monospaced())
                            .keyboardType(.URL)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .focused($editorFocused)
                            .padding(.trailing, text.isEmpty ? 0 : 28)
                        if !text.isEmpty {
                            Button { text = "" } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(Text("Limpiar"))
                        }
                    }
                    HStack {
                        Button {
                            if let s = UIPasteboard.general.string {
                                let clean = s.trimmingCharacters(in: .whitespacesAndNewlines)
                                text = text.isEmpty ? clean : text + "\n" + clean
                            }
                        } label: { Label("Pegar", systemImage: "doc.on.clipboard") }
                        .buttonStyle(.borderless)
                        Spacer()
                        Button { showImporter = true } label: { Label("Archivo .torrent", systemImage: "folder") }
                            .buttonStyle(.borderless)
                    }
                } header: {
                    Text("Pega magnets o enlaces")
                } footer: {
                    Text("Uno por línea, mezclados si quieres. Los magnets van a Torrents y los enlaces a Web.")
                }

                if !files.isEmpty {
                    Section("Archivos .torrent") {
                        ForEach(files, id: \.self) { url in
                            HStack {
                                Label(url.lastPathComponent, systemImage: "doc.fill").lineLimit(2)
                                Spacer()
                                Button(role: .destructive) { files.removeAll { $0 == url } } label: {
                                    Image(systemName: "xmark.circle.fill")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                }

                if !parsed.links.isEmpty || !parsed.ignored.isEmpty {
                    Section("Detectado") {
                        ForEach(parsed.links, id: \.self) { link in
                            DetectedRow(link: link, hoster: hoster(for: link))
                        }
                        ForEach(parsed.ignored, id: \.self) { token in
                            Label {
                                Text(L("No reconocido: ") + token).lineLimit(2)
                            } icon: {
                                Image(systemName: "questionmark.circle").foregroundStyle(.orange)
                            }
                            .font(.footnote)
                        }
                    }
                }

                if !entries.isEmpty {
                    Section {
                        ForEach(entries) { entry in
                            EntryRow(entry: entry, live: entry.ref.flatMap { state.item($0) }) { item, toPhotos in
                                Task { await download(item, toPhotos: toPhotos) }
                            }
                        }
                    } header: {
                        HStack {
                            Text("Resultado")
                            Spacer()
                            Button("Limpiar") { entries.removeAll() }.font(.caption)
                        }
                    }
                }

                Section {
                    if hasWeb {
                        TextField("Contraseña del enlace (opcional)", text: $password)
                            .textContentType(nil)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    Toggle("Solo si ya está en caché", isOn: $onlyCached)
                } footer: {
                    Text("Con “solo si ya está en caché”, TorBox no agrega lo que tendría que descargar desde cero.")
                }

                Section {
                    NavigationLink("Ver sitios compatibles") { HostersView(hosters: hosters) }
                        .disabled(hosters.isEmpty)
                }
            }
            .navigationTitle("Agregar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cerrar") { dismiss() } }
            }
            .safeAreaInset(edge: .bottom) { submitBar }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [Self.torrentType, .data],
                          allowsMultipleSelection: true) { result in
                if case .success(let urls) = result {
                    for u in urls where !files.contains(u) { files.append(u) }
                }
            }
            .onAppear {
                if let initialText, text.isEmpty { text = initialText }
                if let initialFile, !files.contains(initialFile) { files.append(initialFile) }
                if initialText == nil && initialFile == nil { editorFocused = true }
            }
            .task { hosters = (try? await state.api.hosters()) ?? [] }
        }
    }

    /// Botón grande abajo: sube con el teclado y queda junto a lo que pegaste.
    private var submitBar: some View {
        Button {
            Task { await submit() }
        } label: {
            HStack(spacing: 8) {
                if sending { ProgressView().tint(.black) }
                Text(sending ? L("Enviando…")
                     : pendingCount > 1 ? String(format: L("Agregar %d"), pendingCount) : L("Agregar"))
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(pendingCount == 0 || sending)
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(.bar)
    }

    private func hoster(for link: ParsedLink) -> Hoster? {
        guard link.kind == .web, let host = URL(string: link.value)?.host else { return nil }
        return hosters.first { $0.matches(host: host) }
    }

    // MARK: Envío

    private func submit() async {
        let links = parsed.links
        let ignored = parsed.ignored
        let fileQueue = files
        guard !links.isEmpty || !fileQueue.isEmpty else { return }
        sending = true
        editorFocused = false
        defer { sending = false }
        await Notifier.requestPermission()

        var failedOriginals: [String] = []
        var failedFiles: [URL] = []

        for link in links {
            let entry = AddEntry(title: link.displayName, kind: link.isTorrent ? .torrent : .web)
            entries.insert(entry, at: 0)
            do {
                let r: CreateResult
                if link.kind == .magnet {
                    r = try await state.api.addMagnet(link.value, onlyIfCached: onlyCached)
                } else if link.kind == .torrentURL {
                    r = try await state.api.addTorrentURL(link.value, onlyIfCached: onlyCached)
                } else {
                    r = try await state.api.addWebDownload(link: link.value, password: password,
                                                           name: nil, onlyIfCached: onlyCached)
                }
                update(entry.id, with: r)
            } catch {
                failedOriginals.append(link.original)
                setStatus(entry.id, .failed(error.localizedDescription))
            }
        }

        for url in fileQueue {
            let entry = AddEntry(title: url.lastPathComponent, kind: .torrent)
            entries.insert(entry, at: 0)
            do {
                let scoped = url.startAccessingSecurityScopedResource()
                defer { if scoped { url.stopAccessingSecurityScopedResource() } }
                let data = try Data(contentsOf: url)
                let r = try await state.api.addTorrentFile(data, filename: url.lastPathComponent, onlyIfCached: onlyCached)
                update(entry.id, with: r)
            } catch {
                failedFiles.append(url)
                setStatus(entry.id, .failed(error.localizedDescription))
            }
        }

        // Lo que entró bien se borra del cuadro; lo que falló queda para corregirlo.
        text = (failedOriginals + ignored).joined(separator: "\n")
        files = failedFiles
        await state.refresh()
    }

    private func update(_ id: UUID, with r: CreateResult) {
        guard let i = entries.firstIndex(where: { $0.id == id }) else { return }
        if let itemID = r.itemID { entries[i].ref = ItemRef(kind: entries[i].kind, id: itemID) }
        if r.async {
            entries[i].status = .sentAsync
        } else if r.queuedID != nil && r.itemID == nil {
            entries[i].status = .queued
        } else {
            entries[i].status = .added(r.message)
        }
    }

    private func setStatus(_ id: UUID, _ status: AddEntry.Status) {
        if let i = entries.firstIndex(where: { $0.id == id }) { entries[i].status = status }
    }

    private func download(_ item: Torrent, toPhotos: Bool) async {
        do {
            if item.files.count == 1, let f = item.files.first {
                let url = try await state.api.downloadLink(item.kind, id: item.id, fileID: f.id)
                downloads.start(url: url, filename: f.displayName, saveToPhotos: toPhotos && f.canSaveToPhotos)
            } else {
                let url = try await state.api.downloadLink(item.kind, id: item.id, fileID: nil, zip: true)
                downloads.start(url: url, filename: item.name + ".zip")
            }
            Toaster.shared.show(toPhotos ? L("Bajando a Fotos…") : L("Descarga iniciada"), detail: item.name)
        } catch {
            Toaster.shared.show(L("Error"), detail: error.localizedDescription)
        }
    }
}

// MARK: - Filas

struct AddEntry: Identifiable {
    enum Status {
        case sending, added(String?), queued, sentAsync, failed(String)
    }

    let id = UUID()
    let title: String
    let kind: ItemKind
    var status: Status = .sending
    var ref: ItemRef?
}

private struct DetectedRow: View {
    let link: ParsedLink
    let hoster: Hoster?

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: link.isTorrent ? "link.badge.plus" : "globe")
                .foregroundStyle(.green)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(link.isTorrent ? link.displayName : (hoster?.name ?? link.displayName))
                    .font(.subheadline.weight(.semibold))
                    .lineLimit(2)
                if link.isTorrent {
                    Text("Torrent").font(.caption).foregroundStyle(.secondary)
                } else if link.value != link.original {
                    Text("Enlace corregido para TorBox").font(.caption).foregroundStyle(.secondary)
                } else if let note = hoster?.note, !note.isEmpty {
                    Text(note).font(.caption).foregroundStyle(.secondary)
                } else if hoster == nil {
                    Text("Sitio no listado: TorBox lo intentará como enlace directo.")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
            Spacer()
            if let h = hoster {
                Image(systemName: h.status ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                    .foregroundStyle(h.status ? .green : .orange)
            }
        }
    }
}

private struct EntryRow: View {
    let entry: AddEntry
    let live: Torrent?
    let onDownload: (Torrent, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                statusIcon
                Text(live?.name ?? entry.title).font(.subheadline.weight(.semibold)).lineLimit(2)
            }
            statusText
            if let t = live {
                if t.isReady {
                    HStack {
                        Button { onDownload(t, false) } label: {
                            Label("Descargar", systemImage: "arrow.down.circle")
                        }
                        if t.files.count == 1, t.files.first?.canSaveToPhotos == true {
                            Button { onDownload(t, true) } label: {
                                Label("A Fotos", systemImage: "photo.on.rectangle")
                            }
                        }
                    }
                    .buttonStyle(.bordered)
                    .font(.footnote)
                } else if t.failureText == nil {
                    ProgressView(value: min(max(t.progress, 0), 1))
                }
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder private var statusIcon: some View {
        switch entry.status {
        case .sending: ProgressView()
        case .failed: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        default:
            if live?.isReady == true {
                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
            } else {
                Image(systemName: "arrow.triangle.2.circlepath").foregroundStyle(.blue)
            }
        }
    }

    @ViewBuilder private var statusText: some View {
        switch entry.status {
        case .sending:
            Text("Enviando…").font(.caption).foregroundStyle(.secondary)
        case .failed(let msg):
            Text(msg).font(.caption).foregroundStyle(.red)
        case .queued:
            Text("En cola de TorBox: no hay cupos libres ahora").font(.caption).foregroundStyle(.orange)
        case .sentAsync:
            Text("Enviado. Aparecerá en la lista en unos segundos.").font(.caption).foregroundStyle(.secondary)
        case .added(let msg):
            if let t = live {
                if let err = t.failureText, !t.isReady {
                    Text(err).font(.caption).foregroundStyle(.red)
                } else if t.isReady {
                    Text("Listo en TorBox").font(.caption).foregroundStyle(.green)
                } else {
                    Text(Fmt.state(t.downloadState) + " · \(Int(t.progress * 100))%"
                         + (t.downloadSpeed > 0 ? " · ↓ " + Fmt.speed(t.downloadSpeed) : ""))
                        .font(.caption).foregroundStyle(.secondary)
                }
            } else {
                Text(msg ?? L("Agregado")).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Sitios compatibles

struct HostersView: View {
    let hosters: [Hoster]
    @State private var search = ""
    @AppStorage("hosters.showAdult") private var showAdult = false

    private var visible: [Hoster] {
        hosters.filter { showAdult || !$0.nsfw }
            .filter { search.isEmpty || $0.name.localizedCaseInsensitiveContains(search)
                || $0.domains.contains { $0.localizedCaseInsensitiveContains(search) } }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        List(visible) { h in
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(h.name).font(.subheadline.weight(.semibold))
                    Text(h.domains.joined(separator: ", ")).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    if let note = h.note, !note.isEmpty {
                        Text(note).font(.caption2).foregroundStyle(.orange)
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Image(systemName: h.status ? "checkmark.circle.fill" : "xmark.circle")
                        .foregroundStyle(h.status ? .green : .secondary)
                    if let limit = h.dailyLinkLimit, limit > 0 {
                        Text(String(format: L("%d/%d hoy"), h.dailyLinkUsed ?? 0, limit)).font(.caption2).foregroundStyle(.secondary)
                    }
                }
            }
        }
        .safeAreaInset(edge: .top) {
            Toggle(isOn: $showAdult) {
                Text(String(format: L("Mostrar sitios +18 (%d)"), hosters.filter(\.nsfw).count)).font(.footnote)
            }
            .padding(.horizontal).padding(.vertical, 8)
            .background(.bar)
        }
        .searchable(text: $search, prompt: "Buscar sitio")
        .navigationTitle("Sitios compatibles")
    }
}
