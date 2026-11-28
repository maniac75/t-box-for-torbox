import SwiftUI
import QuickLook

struct DownloadsView: View {
    @EnvironmentObject private var downloads: DownloadManager
    @Environment(\.openURL) private var openURL
    @State private var playerURL: URL?
    @State private var previewURL: URL?
    @State private var shareURL: URL?
    @State private var notice: String?

    var body: some View {
        NavigationStack {
            List {
                if !downloads.items.isEmpty {
                    Section {
                        ForEach(downloads.items) { item in
                            HStack(spacing: 12) {
                                DownloadStatusRow(item: item)
                                if item.isActive { PauseButton(item: item) }
                            }
                                .contentShape(Rectangle())
                                .onTapGesture { if downloads.canRetry(item) { downloads.retry(item) } }
                                .swipeActions(edge: .leading) {
                                    if downloads.canRetry(item) {
                                        Button { downloads.retry(item) } label: {
                                            Label("Reintentar", systemImage: "arrow.clockwise")
                                        }
                                        .tint(.blue)
                                    }
                                }
                                .swipeActions {
                                    if item.isActive {
                                        Button(role: .destructive) { downloads.cancel(item) } label: {
                                            Label("Cancelar", systemImage: "stop.circle")
                                        }
                                    }
                                }
                        }
                    } header: {
                        HStack {
                            Text("Descargas")
                            Spacer()
                            Button("Limpiar") { downloads.clearFinished() }.font(.caption)
                        }
                    } footer: {
                        VStack(alignment: .leading, spacing: 6) {
                            if downloads.items.contains(where: { downloads.canRetry($0) }) {
                                Text("Toca una descarga fallida para reintentarla.")
                            }
                            if downloads.usesForegroundDownloads {
                                Label("En tu instalación, iOS no permite descargas en segundo plano. Mantén T-Box abierta mientras descarga y no la cierres desde el selector de apps.",
                                      systemImage: "exclamationmark.triangle")
                                    .foregroundStyle(.orange)
                            }
                        }
                    }
                }

                Section {
                    if downloads.localFiles.isEmpty {
                        Text("Nada todavía. Lo que descargues queda también en la app Archivos › En mi iPhone › T-Box.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                    ForEach(downloads.localFiles, id: \.self) { url in
                        Button { open(url) } label: { LocalFileRow(url: url) }
                            .tint(.primary)
                            .swipeActions {
                                Button(role: .destructive) { downloads.deleteLocal(url) } label: {
                                    Label("Borrar", systemImage: "trash")
                                }
                                Button { shareURL = url } label: { Label("Guardar en…", systemImage: "folder") }
                                    .tint(.blue)
                            }
                            .swipeActions(edge: .leading) {
                                if MediaKind.canSaveToPhotos(url.pathExtension) {
                                    Button { saveToPhotos(url) } label: { Label("A Fotos", systemImage: "photo.on.rectangle") }
                                        .tint(.green)
                                }
                                if url.pathExtension.lowercased() == "zip" {
                                    Button { unzip(url) } label: { Label("Descomprimir", systemImage: "doc.zipper") }
                                        .tint(.orange)
                                }
                                Button { shareURL = url } label: { Label("Compartir", systemImage: "square.and.arrow.up") }
                                    .tint(.gray)
                            }
                    }
                } header: {
                    Text("Guardado en T-Box")
                } footer: {
                    if !downloads.localFiles.isEmpty {
                        Text("Desliza a la izquierda para guardar en otra carpeta o borrar; a la derecha para Fotos, descomprimir o compartir.")
                    }
                }
            }
            .navigationTitle("En el iPhone")
            .refreshable { downloads.reloadLocalFiles() }
            .onAppear { downloads.reloadLocalFiles() }
            .quickLookPreview($previewURL)
            .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("OK", role: .cancel) {}
            }
            .fullScreenCover(item: Binding(get: { playerURL.map(IdentifiedURL.init) },
                                           set: { playerURL = $0?.url })) { item in
                PlayerView(url: item.url)
            }
            .sheet(item: Binding(get: { shareURL.map(IdentifiedURL.init) },
                                 set: { shareURL = $0?.url })) { item in
                ShareSheet(items: [item.url])
            }
        }
    }

    private func open(_ url: URL) {
        if url.hasDirectoryPath {
            // Abre la carpeta directamente en la app Archivos.
            if let files = URL(string: "shareddocuments://" + url.path) { openURL(files) }
        } else if isPlayable(url) {
            playerURL = url
        } else {
            previewURL = url
        }
    }

    private func saveToPhotos(_ url: URL) {
        DownloadManager.saveToPhotos(url) { result in
            DispatchQueue.main.async {
                switch result {
                case .success: notice = L("Guardado en Fotos")
                case .failure(let err): notice = err.localizedDescription
                }
            }
        }
    }

    private func unzip(_ url: URL) {
        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try downloads.unzipLocal(url)
                DispatchQueue.main.async { Toaster.shared.show(L("Descomprimido"), detail: url.lastPathComponent) }
            } catch {
                DispatchQueue.main.async { notice = error.localizedDescription }
            }
        }
    }

    private func isPlayable(_ url: URL) -> Bool {
        ["mp4", "m4v", "mov", "mp3", "m4a", "aac", "wav"].contains(url.pathExtension.lowercased())
    }
}

private struct LocalFileRow: View {
    let url: URL

    private var icon: String {
        if url.hasDirectoryPath { return "folder.fill" }
        let ext = url.pathExtension.lowercased()
        if ["mp4", "m4v", "mov", "mp3", "m4a", "aac", "wav"].contains(ext) { return "play.rectangle" }
        if MediaKind.isPhoto(ext) { return "photo" }
        if ext == "zip" { return "doc.zipper" }
        if ext == "pdf" { return "doc.richtext" }
        return "doc"
    }

    var body: some View {
        HStack {
            Image(systemName: icon).foregroundStyle(.green).frame(width: 24)
            VStack(alignment: .leading) {
                Text(url.lastPathComponent).lineLimit(2)
                if !url.hasDirectoryPath {
                    Text(Fmt.bytes(Int64((try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0)))
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    Text("Carpeta · se abre en Archivos").font(.caption).foregroundStyle(.secondary)
                }
            }
        }
    }
}
