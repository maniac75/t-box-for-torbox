import Foundation
import UIKit

/// Descarga en varias partes: el archivo se pide en 4–6 tramos a la vez (cabeceras Range),
/// cada tramo como tarea propia de la sesión de descargas. Así sigue en segundo plano y,
/// como cada conexión hacia TorBox tiene su propio límite, el total baja varias veces más rápido.
/// Al terminar todos los tramos se unen en el archivo final.
struct TurboJob: Codable {
    let jobID: String
    var itemID: Int
    let original: URL
    let url: URL
    let name: String
    let toPhotos: Bool
    let total: Int64
    let starts: [Int64]
    let ends: [Int64]          // inclusivo
    var done: [Bool]
    var retries: [Int]
    let foreground: Bool
    /// Bytes recibidos en vivo por tramo (no se guarda).
    var received: [Int64] = []

    enum CodingKeys: String, CodingKey {
        case jobID, itemID, original, url, name, toPhotos, total, starts, ends, done, retries, foreground
    }

    var partCount: Int { starts.count }
    func size(_ i: Int) -> Int64 { ends[i] - starts[i] + 1 }

    var receivedTotal: Int64 {
        (0..<partCount).reduce(Int64(0)) { sum, i in
            sum + (done[i] ? size(i) : min(i < received.count ? received[i] : 0, size(i)))
        }
    }

    static let minimumSize: Int64 = 32 * 1024 * 1024

    static func make(original: URL, url: URL, name: String, toPhotos: Bool, total: Int64,
                     itemID: Int, foreground: Bool) -> TurboJob {
        let parts = total >= 256 * 1024 * 1024 ? 6 : 4
        let chunk = total / Int64(parts)
        var starts: [Int64] = [], ends: [Int64] = []
        for i in 0..<parts {
            let s = Int64(i) * chunk
            starts.append(s)
            ends.append(i == parts - 1 ? total - 1 : s + chunk - 1)
        }
        return TurboJob(jobID: UUID().uuidString, itemID: itemID, original: original, url: url, name: name,
                        toPhotos: toPhotos, total: total, starts: starts, ends: ends,
                        done: Array(repeating: false, count: parts), retries: Array(repeating: 0, count: parts),
                        foreground: foreground, received: Array(repeating: 0, count: parts))
    }
}

enum TurboStore {
    static let prefix = "turbo::"

    static var root: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("turbo", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    static func dir(_ jobID: String) -> URL {
        let d = root.appendingPathComponent(jobID, isDirectory: true)
        try? FileManager.default.createDirectory(at: d, withIntermediateDirectories: true)
        return d
    }

    static func partURL(_ jobID: String, _ index: Int) -> URL {
        dir(jobID).appendingPathComponent("\(index).part")
    }

    private static var indexURL: URL { root.appendingPathComponent("jobs.json") }

    static func load() -> [String: TurboJob] {
        guard let data = try? Data(contentsOf: indexURL),
              var jobs = try? JSONDecoder().decode([String: TurboJob].self, from: data) else { return [:] }
        for (k, job) in jobs { jobs[k]?.received = Array(repeating: 0, count: job.partCount) }
        return jobs
    }

    static func save(_ jobs: [String: TurboJob]) {
        if let data = try? JSONEncoder().encode(jobs) { try? data.write(to: indexURL, options: .atomic) }
    }

    static func remove(_ jobID: String) {
        try? FileManager.default.removeItem(at: root.appendingPathComponent(jobID, isDirectory: true))
    }

    static func describe(_ jobID: String, _ index: Int) -> String { "\(prefix)\(jobID)::\(index)" }

    /// "turbo::<job>::<tramo>" → (job, tramo)
    static func parse(_ description: String?) -> (jobID: String, index: Int)? {
        guard let d = description, d.hasPrefix(prefix) else { return nil }
        let parts = d.dropFirst(prefix.count).components(separatedBy: "::")
        guard parts.count == 2, let i = Int(parts[1]) else { return nil }
        return (parts[0], i)
    }

    /// Pide el primer byte para saber el tamaño y si el servidor acepta tramos.
    /// Devuelve la URL final (tras redirecciones) y el tamaño total.
    static func probe(_ url: URL) async -> (URL, Int64)? {
        var req = URLRequest(url: url)
        req.setValue("bytes=0-0", forHTTPHeaderField: "Range")
        req.timeoutInterval = 20
        guard let (_, resp) = try? await URLSession.shared.data(for: req),
              let http = resp as? HTTPURLResponse, http.statusCode == 206,
              let range = http.value(forHTTPHeaderField: "Content-Range"),
              let totalText = range.split(separator: "/").last,
              let total = Int64(totalText), total > 0 else { return nil }
        return (http.url ?? url, total)
    }

    /// Une los tramos en el archivo final, de a 8 MB para no llenar la memoria.
    static func merge(_ job: TurboJob, into dest: URL) throws {
        FileManager.default.createFile(atPath: dest.path, contents: nil)
        let out = try FileHandle(forWritingTo: dest)
        defer { try? out.close() }
        for i in 0..<job.partCount {
            let input = try FileHandle(forReadingFrom: partURL(job.jobID, i))
            defer { try? input.close() }
            while true {
                let chunk = try autoreleasepool { try input.read(upToCount: 8 * 1024 * 1024) }
                guard let chunk, !chunk.isEmpty else { break }
                try out.write(contentsOf: chunk)
            }
        }
        let size = (try? FileManager.default.attributesOfItem(atPath: dest.path)[.size] as? Int64) ?? -1
        guard size == job.total else {
            try? FileManager.default.removeItem(at: dest)
            throw NSError(domain: "T-Box", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: L("El archivo unido quedó incompleto. Reintenta la descarga.")])
        }
    }
}

// MARK: - Descarga en partes dentro del gestor

extension DownloadManager {
    private static var turboCounter = 2_000_000

    /// Ids propios para descargas en partes (no chocan con los de las sesiones).
    func nextTurboID() -> Int {
        DownloadManager.turboCounter += 1
        return DownloadManager.turboCounter
    }

    private func turboSession(_ job: TurboJob) -> URLSession { job.foreground ? foregroundSession : session }

    private func launchPart(_ job: TurboJob, _ i: Int) {
        var req = URLRequest(url: job.url)
        req.setValue("bytes=\(job.starts[i])-\(job.ends[i])", forHTTPHeaderField: "Range")
        let task = turboSession(job).downloadTask(with: req)
        task.taskDescription = TurboStore.describe(job.jobID, i)
        task.resume()
    }

    /// Debe llamarse en el hilo principal.
    func startTurbo(_ job: TurboJob) {
        turboJobs[job.jobID] = job
        TurboStore.save(turboJobs)
        if let i = items.firstIndex(where: { $0.id == job.itemID }) {
            items[i].expected = job.total
            items[i].url = job.original
        }
        Diagnostics.log("DOWNLOAD multipart x\(job.partCount) \(Fmt.bytes(job.total))")
        for i in 0..<job.partCount { launchPart(job, i) }
    }

    func turboProgress(_ jobID: String, _ index: Int, _ written: Int64) {
        DispatchQueue.main.async {
            guard var job = self.turboJobs[jobID], index < job.partCount else { return }
            job.received[index] = written
            self.turboJobs[jobID] = job
            let total = job.receivedTotal
            if let i = self.items.firstIndex(where: { $0.id == job.itemID }) {
                Self.applyProgress(&self.items[i], received: total, expected: job.total)
            }
        }
    }

    /// Se llama en el hilo de la sesión: el archivo temporal se mueve aquí mismo.
    func turboPartFinished(_ jobID: String, _ index: Int, location: URL, response: URLResponse?) {
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 206 else {
            // El servidor mandó el archivo entero (o un error): se sigue con una sola conexión.
            Diagnostics.log("DOWNLOAD multipart part HTTP \(status); falling back to single")
            DispatchQueue.main.async { self.fallBackToSingle(jobID) }
            return
        }
        let dest = TurboStore.partURL(jobID, index)
        try? FileManager.default.removeItem(at: dest)
        do {
            try FileManager.default.moveItem(at: location, to: dest)
        } catch {
            Diagnostics.log("DOWNLOAD multipart move failed: \(Self.describe(error))")
            DispatchQueue.main.async { self.fallBackToSingle(jobID) }
            return
        }
        DispatchQueue.main.async {
            guard var job = self.turboJobs[jobID], index < job.partCount else { return }
            job.done[index] = true
            job.received[index] = job.size(index)
            self.turboJobs[jobID] = job
            TurboStore.save(self.turboJobs)
            self.turboProgress(jobID, index, job.size(index))
            if job.done.allSatisfy({ $0 }) { self.mergeTurbo(job) }
        }
    }

    func turboPartFailed(_ jobID: String, _ index: Int, error: Error) {
        let ns = error as NSError
        if ns.code == NSURLErrorCancelled { return }
        Diagnostics.log("DOWNLOAD multipart part \(index) error: \(Self.describe(error))")
        DispatchQueue.main.async {
            guard var job = self.turboJobs[jobID], index < job.partCount, !job.done[index] else { return }
            // iOS no pudo crear el archivo en la sesión de fondo: se sigue por la vía normal, en una sola conexión.
            if ns.domain == NSURLErrorDomain, [NSURLErrorCannotCreateFile, NSURLErrorCannotOpenFile,
                                                NSURLErrorCannotWriteToFile, NSURLErrorCannotMoveFile].contains(ns.code) {
                Self.useForeground = true
                self.fallBackToSingle(jobID)
                return
            }
            if job.retries[index] < 3 {
                job.retries[index] += 1
                job.received[index] = 0
                self.turboJobs[jobID] = job
                TurboStore.save(self.turboJobs)
                let delay = Double(job.retries[index]) * 2
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
                    if let j = self.turboJobs[jobID] { self.launchPart(j, index) }
                }
            } else {
                self.dropTurbo(jobID)
                self.update(job.itemID) { $0.status = .failed(error.localizedDescription) }
            }
        }
    }

    /// Cancela los tramos y repite la descarga como una sola, conservando la fila.
    private func fallBackToSingle(_ jobID: String) {
        guard let job = turboJobs[jobID] else { return }
        dropTurbo(jobID)
        items.removeAll { $0.id == job.itemID }
        startSingle(url: job.original, filename: job.name, saveToPhotos: job.toPhotos)
    }

    /// Cancela las tareas de un trabajo y borra sus tramos.
    func dropTurbo(_ jobID: String) {
        turboJobs[jobID] = nil
        TurboStore.save(turboJobs)
        for s in [session, foregroundSession] {
            s.getAllTasks { tasks in
                tasks.filter { TurboStore.parse($0.taskDescription)?.jobID == jobID }.forEach { $0.cancel() }
            }
        }
        DispatchQueue.global(qos: .utility).asyncAfter(deadline: .now() + 1) { TurboStore.remove(jobID) }
    }

    private func mergeTurbo(_ job: TurboJob) {
        turboJobs[job.jobID] = nil
        TurboStore.save(turboJobs)
        // Unir 1 GB toma un par de segundos: se pide tiempo por si la app está en segundo plano.
        var bg = UIBackgroundTaskIdentifier.invalid
        bg = UIApplication.shared.beginBackgroundTask(withName: "merge") {
            UIApplication.shared.endBackgroundTask(bg)
            bg = .invalid
        }
        DispatchQueue.global(qos: .userInitiated).async {
            defer {
                TurboStore.remove(job.jobID)
                DispatchQueue.main.async { if bg != .invalid { UIApplication.shared.endBackgroundTask(bg) } }
            }
            let dest = Self.uniqueDestination(for: job.name)
            do {
                try TurboStore.merge(job, into: dest)
            } catch {
                Diagnostics.log("DOWNLOAD multipart merge failed: \(Self.describe(error))")
                self.update(job.itemID) { $0.status = .failed(error.localizedDescription) }
                return
            }
            self.finalize(dest, name: job.name, toPhotos: job.toPhotos, id: job.itemID)
        }
    }

    /// Al abrir la app: vuelve a mostrar los trabajos guardados y relanza los tramos que quedaron sin tarea.
    func restoreTurbo(live: Set<String>) {
        for (id, var job) in turboJobs {
            let row = nextTurboID()
            job.itemID = row
            turboJobs[id] = job
            var item = Item(id: row, name: job.name, progress: 0, received: 0, expected: job.total,
                            status: .running, toPhotos: job.toPhotos, task: nil, url: job.original)
            Self.applyProgress(&item, received: job.receivedTotal, expected: job.total)
            items.insert(item, at: 0)
            if job.done.allSatisfy({ $0 }) {
                mergeTurbo(job)
                continue
            }
            for i in 0..<job.partCount where !job.done[i] && !live.contains("\(id)::\(i)") {
                launchPart(job, i)
            }
        }
        TurboStore.save(turboJobs)
    }
}
