import SwiftUI
import QuickLook

struct TorrentDetailView: View {
    @AppStorage("library.cleanTitles") private var cleanTitles = true
    let ref: ItemRef

    @EnvironmentObject private var state: AppState
    @EnvironmentObject private var downloads: DownloadManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var selectedFile: TorrentFile?
    @State private var working = false
    @State private var playerURL: URL?
    @State private var shareURL: URL?
    @State private var toast: String?
    @State private var confirmDelete = false
    @State private var previewURL: URL?
    @State private var workingText: String?
    @State private var airlockBusy = false
    @State private var renaming = false
    @State private var newName = ""
    @State private var airlockError: String?

    var body: some View {
        Group {
            if let t = state.item(ref) {
                content(t)
            } else {
                ContentUnavailableView("No encontrado", systemImage: "questionmark.folder")
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if working {
                ProgressView(workingText ?? L("Pidiendo enlace a TorBox…"))
                    .padding(20)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
            }
        }
        .overlay(alignment: .bottom) {
            if let toast {
                Text(toast)
                    .font(.footnote.weight(.semibold))
                    .padding(.horizontal, 14).padding(.vertical, 10)
                    .background(.regularMaterial, in: Capsule())
                    .padding(.bottom, 24)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .fullScreenCover(item: Binding(get: { playerURL.map(IdentifiedURL.init) },
                                       set: { playerURL = $0?.url })) { item in
            PlayerView(url: item.url)
        }
        .quickLookPreview($previewURL)
        .sheet(item: Binding(get: { shareURL.map(IdentifiedURL.init) },
                             set: { shareURL = $0?.url })) { item in
            ShareSheet(items: [item.url])
        }
    }

    @ViewBuilder
    private func content(_ t: Torrent) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    let clean = CleanTitle.cached(t.name)
                    Text(cleanTitles ? clean : t.name).font(.headline).textSelection(.enabled)
                    if cleanTitles && clean != t.name {
                        Text(t.name).font(.caption).foregroundStyle(.secondary).textSelection(.enabled)
                    }
                }
                HStack { StateBadge(torrent: t); Spacer(); Text(Fmt.bytes(t.size)).foregroundStyle(.secondary) }
                if !t.isReady && t.failureText == nil {
                    ProgressView(value: min(max(t.progress, 0), 1))
                    LabeledContent("Velocidad", value: "↓ \(Fmt.speed(t.downloadSpeed))  ↑ \(Fmt.speed(t.uploadSpeed))")
                    if let eta = Fmt.eta(t.eta) { LabeledContent("Tiempo restante", value: eta) }
                    if let s = t.seeds, let p = t.peers { LabeledContent("Seeds / peers", value: "\(s) / \(p)") }
                }
            }

            if t.isReady {
                Section {
                    Toggle(isOn: Binding(get: { t.airlocked }, set: { on in
                        airlockBusy = true
                        Task {
                            airlockError = await state.setAirlock(t, on: on)
                            airlockBusy = false
                        }
                    })) {
                        Label("Guardar en AirLock", systemImage: t.airlocked ? "lock.fill" : "lock.open")
                    }
                    .disabled(airlockBusy || state.user?.isFree == true)
                    if let e = airlockError {
                        Text(e).font(.caption).foregroundStyle(.red)
                    }
                } footer: {
                    Text(state.user?.isFree == true
                         ? L("AirLock requiere un plan pagado de TorBox.")
                         : L("TorBox no borra lo que está en AirLock en la limpieza de 30 días sin uso. Cuenta para el espacio de AirLock de tu plan."))
                }

                Section(String(format: L("Archivos (%d)"), t.files.count)) {
                    ForEach(t.sortedFiles) { f in
                        Button { selectedFile = f } label: { FileRow(file: f) }
                            .tint(.primary)
                    }
                }
            } else {
                Section {
                    if let err = t.failureText {
                        Label(err, systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.red)
                            .textSelection(.enabled)
                    } else {
                        Text("Los archivos estarán disponibles cuando TorBox termine de descargar.")
                            .foregroundStyle(.secondary).font(.footnote)
                    }
                } footer: {
                    if t.failureText != nil {
                        Text("TorBox no pudo bajar esto. Puedes borrarlo y volver a agregarlo más tarde.")
                    }
                }
            }
        }
        .refreshable { await state.refresh() }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { state.toggleFavorite(t) } label: {
                    Image(systemName: state.isFavorite(t) ? "star.fill" : "star")
                        .foregroundStyle(state.isFavorite(t) ? .yellow : .accentColor)
                }
                .accessibilityLabel(state.isFavorite(t) ? L("Quitar de favoritos") : L("Agregar a favoritos"))
            }
            ToolbarItem(placement: .topBarTrailing) {
                Menu {
                    if t.isReady && t.files.count > 1 {
                        Button { Task { await downloadZip(t) } } label: {
                            Label("Descargar todo (.zip)", systemImage: "doc.zipper")
                        }
                    }
                    if !t.isReady && t.kind == .torrent {
                        Button { Task { await state.reannounce(t) } } label: {
                            Label("Buscar más peers", systemImage: "arrow.triangle.2.circlepath")
                        }
                    }
                    if t.isReady {
                        Button { newName = t.name; renaming = true } label: {
                            Label("Renombrar", systemImage: "pencil")
                        }
                    }
                    if let hash = t.hash {
                        Button { UIPasteboard.general.string = hash; flash(L("Hash copiado")) } label: {
                            Label("Copiar hash", systemImage: "number")
                        }
                    }
                    Divider()
                    Button(role: .destructive) { confirmDelete = true } label: {
                        Label("Eliminar de TorBox", systemImage: "trash")
                    }
                } label: { Image(systemName: "ellipsis.circle") }
            }
        }
        .confirmationDialog(selectedFile?.displayName ?? "",
                            isPresented: Binding(get: { selectedFile != nil }, set: { if !$0 { selectedFile = nil } }),
                            titleVisibility: .visible,
                            presenting: selectedFile) { f in
            fileActions(t, f)
        }
        .alert("Renombrar", isPresented: $renaming) {
            TextField("Nombre", text: $newName)
            Button("Cancelar", role: .cancel) {}
            Button("Guardar") {
                let name = newName
                Task { if let e = await state.rename(t, to: name) { flash(e) } else { flash(L("Renombrado")) } }
            }
        } message: {
            Text("Cambia el nombre en tu cuenta de TorBox.")
        }
        .confirmationDialog("¿Eliminar de TorBox?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Eliminar", role: .destructive) {
                Task { await state.delete(t); dismiss() }
            }
        }
    }

    @ViewBuilder
    private func fileActions(_ t: Torrent, _ f: TorrentFile) -> some View {
        if f.isNativelyPlayable {
            Button("Reproducir aquí") { run(t, f) { url in playerURL = url } }
        }
        if !f.isVideo {
            Button("Ver") { preview(t, f) }
        }
        if f.isVideo || f.isNativelyPlayable {
            Button("Abrir en Infuse") { run(t, f) { url in openExternal("infuse://x-callback-url/play?url=", url) } }
            Button("Abrir en VLC") { run(t, f) { url in openExternal("vlc-x-callback://x-callback-url/stream?url=", url) } }
            Button("Abrir en VidHub") { run(t, f) { url in openExternal("open-vidhub://x-callback-url/play?url=", url, filename: f.displayName) } }
        }
        if f.canSaveToPhotos {
            Button("Guardar en Fotos") {
                run(t, f) { url in
                    downloads.start(url: url, filename: f.displayName, saveToPhotos: true)
                    flash(L("Bajando a Fotos…"))
                }
            }
        }
        Button("Descargar a Archivos") {
            run(t, f) { url in
                downloads.start(url: url, filename: f.displayName)
                flash(L("Descarga iniciada"))
            }
        }
        Button("Copiar enlace") { run(t, f) { url in UIPasteboard.general.string = url.absoluteString; flash(L("Enlace copiado (válido ~3 h)")) } }
        Button("Compartir enlace…") { run(t, f) { url in shareURL = url } }
        Button("Cancelar", role: .cancel) {}
    }

    /// Vista previa (PDF, imágenes, documentos, audio): baja el archivo a una carpeta temporal y lo abre.
    private func preview(_ t: Torrent, _ f: TorrentFile) {
        Task {
            working = true
            workingText = L("Preparando vista previa…")
            defer { working = false; workingText = nil }
            do {
                let remote = try await state.api.downloadLink(t.kind, id: t.id, fileID: f.id)
                let (tmp, _) = try await URLSession.shared.download(from: remote)
                let dir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent("preview", isDirectory: true)
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let dest = dir.appendingPathComponent(f.displayName)
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.moveItem(at: tmp, to: dest)
                previewURL = dest
            } catch {
                flash(error.localizedDescription)
            }
        }
    }

    private func run(_ t: Torrent, _ f: TorrentFile, _ then: @escaping (URL) -> Void) {
        Task {
            working = true
            defer { working = false }
            do { then(try await state.api.downloadLink(t.kind, id: t.id, fileID: f.id)) }
            catch { flash(error.localizedDescription) }
        }
    }

    private func downloadZip(_ t: Torrent) async {
        working = true
        defer { working = false }
        do {
            let url = try await state.api.downloadLink(t.kind, id: t.id, fileID: nil, zip: true)
            downloads.start(url: url, filename: t.name + ".zip")
            flash(L("Descarga iniciada"))
        } catch { flash(error.localizedDescription) }
    }

    private func openExternal(_ prefix: String, _ url: URL, filename: String? = nil) {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        guard let encoded = url.absoluteString.addingPercentEncoding(withAllowedCharacters: allowed) else { return }
        var link = prefix + encoded
        if let filename {
            guard let encodedName = filename.addingPercentEncoding(withAllowedCharacters: allowed) else { return }
            link += "&filename=" + encodedName
        }
        guard let target = URL(string: link) else { return }
        openURL(target) { accepted in
            if !accepted { flash(L("Esa app no está instalada")) }
        }
    }

    private func flash(_ text: String) {
        withAnimation { toast = text }
        Task {
            try? await Task.sleep(nanoseconds: 2_200_000_000)
            withAnimation { if toast == text { toast = nil } }
        }
    }
}

struct FileRow: View {
    let file: TorrentFile

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: file.isVideo ? "film" : (file.isImage ? "photo" : (file.fileExtension == "srt" ? "captions.bubble" : "doc")))
                .foregroundStyle(file.isVideo || file.isImage ? .green : .secondary)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayName).font(.subheadline).lineLimit(3)
                Text(Fmt.bytes(file.size) + (file.fileExtension.isEmpty ? "" : " · " + file.fileExtension.uppercased()))
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

struct IdentifiedURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }
    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}
