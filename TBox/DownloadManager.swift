import Foundation
import SwiftUI
import Photos
import ZIPFoundation

/// Descargas al iPhone con una sesión en segundo plano: siguen aunque cierres la app.
/// Los archivos quedan en Archivos › En mi iPhone › T-Box › Descargas.
final class DownloadManager: NSObject, ObservableObject, URLSessionDownloadDelegate {
    static let shared = DownloadManager()

    enum Status: Equatable {
        case running, done, savedToPhotos, failed(String)
    }

    /// Prefijo en taskDescription: sobrevive si la app se cierra durante la descarga.
    private static let photosPrefix = "photos::"

    private static func parse(_ description: String?) -> (name: String, toPhotos: Bool) {
        let d = description ?? "Descarga"
        if d.hasPrefix(photosPrefix) { return (String(d.dropFirst(photosPrefix.count)), true) }
        return (d, false)
    }

    struct Item: Identifiable {
        var id: Int
        let name: String
        var progress: Double
        var received: Int64
        var expected: Int64
        var status: Status
        var toPhotos: Bool = false
        var savedTo: String?
        var task: URLSessionDownloadTask?
    }

    @Published var items: [Item] = []
    @Published var localFiles: [URL] = []
    var backgroundCompletion: (() -> Void)?

    private lazy var session: URLSession = {
        let c = URLSessionConfiguration.background(withIdentifier: "io.github.maniac75.tbox.downloads")
        c.sessionSendsLaunchEvents = true
        c.isDiscretionary = false
        c.allowsCellularAccess = true
        return URLSession(configuration: c, delegate: self, delegateQueue: nil)
    }()

    /// Plan B: sesión normal (no de fondo). Algunas instalaciones por sideload no dejan que el servicio
    /// de descargas de iOS cree archivos ("Cannot create file"); ahí se reintenta por esta vía.
    private lazy var foregroundSession: URLSession = {
        let c = URLSessionConfiguration.default
        c.allowsCellularAccess = true
        c.timeoutIntervalForResource = 60 * 60 * 24
        return URLSession(configuration: c, delegate: self, delegateQueue: nil)
    }()

    /// Los ids de la sesión normal se desplazan para no chocar con los de la sesión de fondo.
    private static let foregroundOffset = 1_000_000
    private func itemID(_ session: URLSession, _ task: URLSessionTask) -> Int {
        session === foregroundSession ? task.taskIdentifier + Self.foregroundOffset : task.taskIdentifier
    }

    /// Si la sesión de fondo ya falló así una vez, las siguientes descargas van directo por la normal.
    private static var useForeground: Bool {
        get { UserDefaults.standard.bool(forKey: "downloads.useForeground") }
        set { UserDefaults.standard.set(newValue, forKey: "downloads.useForeground") }
    }

    private static let fallbackCodes: Set<Int> = [NSURLErrorCannotCreateFile, NSURLErrorCannotOpenFile,
                                                  NSURLErrorCannotWriteToFile, NSURLErrorCannotMoveFile]

    static var downloadsDir: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let dir = docs.appendingPathComponent("Descargas", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    override init() {
        super.init()
        _ = session   // reconecta con descargas que siguieron en segundo plano
        reloadLocalFiles()
        session.getAllTasks { [weak self] tasks in
            let restored: [Item] = tasks.compactMap { t in
                guard let dt = t as? URLSessionDownloadTask, t.state == .running || t.state == .suspended else { return nil }
                let info = Self.parse(dt.taskDescription)
                return Item(id: dt.taskIdentifier, name: info.name, progress: 0,
                            received: 0, expected: 0, status: .running, toPhotos: info.toPhotos, task: dt)
            }
            DispatchQueue.main.async { self?.items = restored }
        }
    }

    func start(url: URL, filename: String, saveToPhotos: Bool = false) {
        let s = Self.useForeground ? foregroundSession : session
        let task = s.downloadTask(with: url)
        task.taskDescription = (saveToPhotos ? Self.photosPrefix : "") + filename
        let item = Item(id: itemID(s, task), name: filename, progress: 0, received: 0, expected: 0,
                        status: .running, toPhotos: saveToPhotos, task: task)
        DispatchQueue.main.async { self.items.insert(item, at: 0) }
        task.resume()
    }

    func cancel(_ item: Item) {
        item.task?.cancel()
        items.removeAll { $0.id == item.id }
    }

    /// Cancela todo lo que está bajando, incluidas tareas que quedaron colgadas en la sesión de fondo.
    func cancelAll() {
        session.getAllTasks { tasks in tasks.forEach { $0.cancel() } }
        DispatchQueue.main.async { self.items.removeAll { $0.status == .running } }
    }

    func clearFinished() {
        items.removeAll { $0.status != .running }
    }

    func reloadLocalFiles() {
        let fm = FileManager.default
        let urls = (try? fm.contentsOfDirectory(at: Self.downloadsDir,
                                                 includingPropertiesForKeys: [.contentModificationDateKey],
                                                 options: [.skipsHiddenFiles])) ?? []
        let sorted = urls.sorted {
            let a = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let b = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return a > b
        }
        DispatchQueue.main.async { self.localFiles = sorted }
    }

    func deleteLocal(_ url: URL) {
        try? FileManager.default.removeItem(at: url)
        reloadLocalFiles()
    }

    private func update(_ id: Int, _ change: @escaping (inout Item) -> Void) {
        DispatchQueue.main.async {
            if let i = self.items.firstIndex(where: { $0.id == id }) { change(&self.items[i]) }
        }
    }

    private static func uniqueDestination(for name: String) -> URL {
        let clean = name.replacingOccurrences(of: "/", with: "_")
        var dest = downloadsDir.appendingPathComponent(clean)
        let base = (clean as NSString).deletingPathExtension
        let ext = (clean as NSString).pathExtension
        var n = 1
        while FileManager.default.fileExists(atPath: dest.path) {
            let candidate = ext.isEmpty ? "\(base) (\(n))" : "\(base) (\(n)).\(ext)"
            dest = downloadsDir.appendingPathComponent(candidate)
            n += 1
        }
        return dest
    }

    // MARK: Fotos

    enum PhotosError: LocalizedError {
        case denied, unsupported
        var errorDescription: String? {
            switch self {
            case .denied: return L("Sin permiso para agregar a Fotos (Ajustes › T-Box › Fotos).")
            case .unsupported: return L("Formato no compatible con Fotos.")
            }
        }
    }

    /// Guarda una foto o video en la app Fotos (pide solo permiso de "agregar").
    static func saveToPhotos(_ url: URL, completion: @escaping (Result<Void, Error>) -> Void) {
        let ext = url.pathExtension
        guard MediaKind.canSaveToPhotos(ext) else { completion(.failure(PhotosError.unsupported)); return }
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                completion(.failure(PhotosError.denied)); return
            }
            PHPhotoLibrary.shared().performChanges({
                if MediaKind.isPhoto(ext) {
                    PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
                } else {
                    PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
                }
            }) { ok, error in
                if ok { completion(.success(())) }
                else { completion(.failure(error ?? PhotosError.unsupported)) }
            }
        }
    }

    // MARK: URLSessionDownloadDelegate

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64,
                    totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        update(itemID(session, downloadTask)) { item in
            item.received = totalBytesWritten
            item.expected = totalBytesExpectedToWrite
            item.progress = totalBytesExpectedToWrite > 0 ? Double(totalBytesWritten) / Double(totalBytesExpectedToWrite) : 0
        }
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        // El archivo temporal se borra al salir de este método: hay que moverlo aquí mismo.
        let status = (downloadTask.response as? HTTPURLResponse)?.statusCode ?? 200
        guard (200..<300).contains(status) else {
            Diagnostics.log("DOWNLOAD HTTP \(status) \(downloadTask.taskDescription ?? "")")
            update(itemID(session, downloadTask)) { $0.status = .failed("HTTP \(status)") }
            return
        }
        let info = Self.parse(downloadTask.taskDescription ?? downloadTask.response?.suggestedFilename)
        let dest = Self.uniqueDestination(for: info.name)
        let id = itemID(session, downloadTask)
        do {
            try FileManager.default.moveItem(at: location, to: dest)
        } catch {
            Diagnostics.log("DOWNLOAD move failed \(info.name): \(Self.describe(error))")
            update(id) { $0.status = .failed(error.localizedDescription) }
            return
        }
        update(id) { $0.progress = 1 }
        if info.toPhotos {
            Self.saveToPhotos(dest) { [weak self] result in
                switch result {
                case .success:
                    try? FileManager.default.removeItem(at: dest)   // ya quedó en Fotos; no duplicar espacio
                    self?.update(id) { $0.status = .savedToPhotos }
                    Notifier.announce(L("Guardado en Fotos"), detail: info.name, id: "dl-\(id)")
                case .failure(let err):
                    self?.update(id) { $0.status = .failed(L("Quedó en Archivos, pero no en Fotos: ") + err.localizedDescription) }
                }
                self?.reloadLocalFiles()
            }
            return
        }
        // Descomprimir (si está activado) y llevar a la carpeta elegida, fuera del hilo de la sesión.
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self else { return }
            var result = dest
            if AppSettings.unzipAfterDownload, dest.pathExtension.lowercased() == "zip",
               let folder = try? Self.unzip(dest) {
                try? FileManager.default.removeItem(at: dest)
                result = folder
            }
            let saved = Self.moveToChosenFolder(result)
            self.update(id) { $0.status = .done; $0.savedTo = saved }
            UserDefaults.standard.set(UserDefaults.standard.integer(forKey: "support.completed") + 1, forKey: "support.completed")
            self.reloadLocalFiles()
            Notifier.announce(L("Descarga terminada"), detail: info.name, id: "dl-\(id)")
        }
    }

    // MARK: Carpeta elegida y descompresión

    /// Mueve el archivo a la carpeta que eligió el usuario. Devuelve el nombre de esa carpeta,
    /// o nil si no hay una elegida o no se pudo (en ese caso el archivo queda en la carpeta de T-Box).
    @discardableResult
    static func moveToChosenFolder(_ url: URL) -> String? {
        guard let folder = AppSettings.resolveDestination() else { return nil }
        let scoped = folder.startAccessingSecurityScopedResource()
        defer { if scoped { folder.stopAccessingSecurityScopedResource() } }
        var target = folder.appendingPathComponent(url.lastPathComponent)
        var n = 1
        let base = url.deletingPathExtension().lastPathComponent
        let ext = url.pathExtension
        while FileManager.default.fileExists(atPath: target.path) {
            target = folder.appendingPathComponent(ext.isEmpty ? "\(base) (\(n))" : "\(base) (\(n)).\(ext)")
            n += 1
        }
        var moveError: NSError?
        var coordError: NSError?
        NSFileCoordinator().coordinate(writingItemAt: target, options: .forReplacing, error: &coordError) { dst in
            do { try FileManager.default.moveItem(at: url, to: dst) } catch { moveError = error as NSError }
        }
        if let e = moveError ?? coordError {
            Diagnostics.log("MOVE to chosen folder failed: \(e.localizedDescription)")
            return nil
        }
        return AppSettings.destinationName ?? folder.lastPathComponent
    }

    /// Descomprime un .zip en una carpeta con su mismo nombre, junto al archivo.
    static func unzip(_ zip: URL) throws -> URL {
        var folder = zip.deletingPathExtension()
        var n = 1
        while FileManager.default.fileExists(atPath: folder.path) {
            folder = zip.deletingLastPathComponent().appendingPathComponent(zip.deletingPathExtension().lastPathComponent + " (\(n))")
            n += 1
        }
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        do {
            try FileManager.default.unzipItem(at: zip, to: folder)
        } catch {
            try? FileManager.default.removeItem(at: folder)
            Diagnostics.log("UNZIP failed: \(error.localizedDescription)")
            throw error
        }
        return folder
    }

    /// Descomprimir a pedido desde la lista de archivos.
    func unzipLocal(_ zip: URL) throws {
        _ = try Self.unzip(zip)
        try? FileManager.default.removeItem(at: zip)
        reloadLocalFiles()
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error else { return }
        let ns = error as NSError
        if ns.code == NSURLErrorCancelled { return }
        let old = itemID(session, task)
        Diagnostics.log("DOWNLOAD error \(task.taskDescription ?? "") [\(session === foregroundSession ? "normal" : "background")]: \(Self.describe(error))")
        // Plan B: si iOS no pudo crear el archivo en la sesión de fondo, se repite como descarga normal.
        if session !== foregroundSession, ns.domain == NSURLErrorDomain, Self.fallbackCodes.contains(ns.code),
           let url = task.originalRequest?.url {
            Self.useForeground = true
            Diagnostics.log("DOWNLOAD retrying as normal download")
            let retry = foregroundSession.downloadTask(with: url)
            retry.taskDescription = task.taskDescription
            let newID = itemID(foregroundSession, retry)
            DispatchQueue.main.async {
                if let i = self.items.firstIndex(where: { $0.id == old }) {
                    self.items[i].id = newID
                    self.items[i].task = retry
                    self.items[i].status = .running
                    self.items[i].progress = 0
                }
                retry.resume()
            }
            return
        }
        update(old) { $0.status = .failed(error.localizedDescription) }
    }

    /// Todo el detalle de un error, para el diagnóstico: dominio, código, ruta y error interno.
    static func describe(_ error: Error) -> String {
        let ns = error as NSError
        var parts = ["\(ns.localizedDescription) (\(ns.domain) \(ns.code))"]
        if let p = ns.userInfo[NSFilePathErrorKey] { parts.append("path=\(p)") }
        // Solo el dominio del enlace: la URL completa puede llevar tokens.
        if let u = ns.userInfo[NSURLErrorFailingURLErrorKey] as? URL, let host = u.host { parts.append("host=\(host)") }
        var inner = ns.userInfo[NSUnderlyingErrorKey] as? NSError
        var depth = 0
        while let e = inner, depth < 3 {
            parts.append("underlying: \(e.localizedDescription) (\(e.domain) \(e.code))")
            if let p = e.userInfo[NSFilePathErrorKey] { parts.append("path=\(p)") }
            inner = e.userInfo[NSUnderlyingErrorKey] as? NSError
            depth += 1
        }
        return parts.joined(separator: " | ")
    }

    func urlSessionDidFinishEvents(forBackgroundURLSession session: URLSession) {
        DispatchQueue.main.async {
            self.backgroundCompletion?()
            self.backgroundCompletion = nil
        }
    }
}
