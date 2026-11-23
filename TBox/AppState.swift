import Foundation
import SwiftUI

@MainActor
final class AppState: ObservableObject {
    nonisolated static let keyAccount = "torbox_api_key"

    @Published private(set) var apiKey: String?
    @Published var torrents: [Torrent] = []
    @Published var webDownloads: [Torrent] = []
    @Published var user: UserInfo?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var queuedTorrents: [QueuedItem] = []
    @Published var queuedWeb: [QueuedItem] = []
    @Published var referral: ReferralInfo?
    /// Favoritos: se guardan solo en el iPhone ("torrent-123", "web-45").
    @Published private(set) var favorites: Set<String> =
        Set(UserDefaults.standard.stringArray(forKey: "favorites") ?? [])

    func queued(_ kind: ItemKind) -> [QueuedItem] { kind == .torrent ? queuedTorrents : queuedWeb }
    private var transientFailures = 0

    /// Entradas desde Safari, Archivos o un Atajo; abren la hoja única de "Agregar".
    @Published var showAdd = false
    @Published var incomingText: String?
    @Published var incomingTorrentFile: URL?

    private var tracker = ReadyTracker()

    let api: TorBoxAPI
    private var pollTask: Task<Void, Never>?

    init() {
        let stored = Keychain.load(account: Self.keyAccount)
        apiKey = stored
        api = TorBoxAPI(apiKey: stored)
        Diagnostics.shared.setSecret(stored)
        if let stored, !stored.isEmpty { shareKeyWithExtension(stored) }
    }

    /// Copia la key al llavero compartido para que la extensión de Compartir pueda enviar directo.
    private func shareKeyWithExtension(_ key: String) {
        let ok = SharedKeychain.save(key)
        UserDefaults.standard.set(ok, forKey: "share.keychainOK")
        if !ok { Diagnostics.log("SHARE keychain group not available; the share extension will open T-Box instead") }
    }

    var isLoggedIn: Bool { !(apiKey ?? "").isEmpty }

    // MARK: Sesión

    func login(with key: String) async -> Bool {
        let trimmed = key.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return false }
        api.apiKey = trimmed
        Diagnostics.shared.setSecret(trimmed)
        do {
            user = try await api.me()
            Keychain.save(trimmed, account: Self.keyAccount)
            shareKeyWithExtension(trimmed)
            apiKey = trimmed
            errorMessage = nil
            await refresh()
            return true
        } catch {
            api.apiKey = apiKey
            Diagnostics.shared.setSecret(apiKey)
            Diagnostics.log("LOGIN failed: \(error.localizedDescription)")
            errorMessage = error.localizedDescription
            return false
        }
    }

    func logout() {
        stopPolling()
        Keychain.delete(account: Self.keyAccount)
        SharedKeychain.delete()
        apiKey = nil
        api.apiKey = nil
        torrents = []
        webDownloads = []
        user = nil
    }

    // MARK: Datos

    /// Lo que TorBox está procesando ahora (sin contar los que fallaron).
    var activeInTorBox: [Torrent] {
        (torrents + webDownloads).filter { !$0.isReady && $0.errorText == nil }
    }

    func items(_ kind: ItemKind) -> [Torrent] {
        kind == .torrent ? torrents : webDownloads
    }

    private func favKey(_ t: Torrent) -> String { "\(t.kind.rawValue)-\(t.id)" }

    func isFavorite(_ t: Torrent) -> Bool { favorites.contains(favKey(t)) }

    func toggleFavorite(_ t: Torrent) {
        let k = favKey(t)
        if favorites.contains(k) { favorites.remove(k) } else { favorites.insert(k) }
        UserDefaults.standard.set(Array(favorites), forKey: "favorites")
    }

    /// Marca o desmarca varios como favoritos de una vez.
    func setFavorite(_ list: [Torrent], _ on: Bool) {
        for t in list {
            if on { favorites.insert(favKey(t)) } else { favorites.remove(favKey(t)) }
        }
        UserDefaults.standard.set(Array(favorites), forKey: "favorites")
    }

    func item(_ ref: ItemRef) -> Torrent? {
        items(ref.kind).first { $0.id == ref.id }
    }

    private var refreshTask: Task<Void, Never>?

    /// Un solo refresco a la vez. Corre fuera del ciclo de vida de las vistas:
    /// si una pantalla desaparece o la tarea que lo pidió se cancela, el refresco igual termina.
    func refresh() async {
        guard isLoggedIn else { return }
        if let running = refreshTask {
            await running.value
            return
        }
        let task = Task { [weak self] in
            guard let self else { return }
            await self.performRefresh()
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func performRefresh() async {
        isLoading = true
        defer { isLoading = false }
        var errors: [String] = []
        var transientOnly = true
        var loaded: Set<ItemKind> = []
        // La cola se consulta aparte y sin mostrar errores: es información complementaria.
        async let qt = try? api.queued(.torrent)
        async let qw = try? api.queued(.web)
        async let t = api.items(.torrent)
        async let w = api.items(.web)
        do { torrents = Self.sorted(try await t); loaded.insert(.torrent) }
        catch where !TorBoxAPI.isCancellation(error) {
            errors.append("Torrents: " + error.localizedDescription)
            if !TorBoxAPI.isTransient(error) { transientOnly = false }
        }
        catch {}
        do { webDownloads = Self.sorted(try await w); loaded.insert(.web) }
        catch where !TorBoxAPI.isCancellation(error) {
            errors.append("Web: " + error.localizedDescription)
            if !TorBoxAPI.isTransient(error) { transientOnly = false }
        }
        catch {}
        if let q = await qt { queuedTorrents = q }
        if let q = await qw { queuedWeb = q }
        // Un corte de red aislado (app en segundo plano, cambio de wifi) no se muestra: se reintenta en la siguiente vuelta.
        if !errors.isEmpty && transientOnly {
            transientFailures += 1
            if transientFailures < 3 { errors.removeAll() }
        } else if errors.isEmpty {
            transientFailures = 0
        }
        errorMessage = errors.isEmpty ? nil : errors.joined(separator: "\n")
        if !loaded.isEmpty {
            for item in tracker.process(torrents + webDownloads, kinds: loaded) {
                Notifier.announce(L("Listo en TorBox"), detail: item.name, id: "ready-\(item.kind.rawValue)-\(item.id)")
            }
        }
        if user == nil { user = try? await api.me() }
    }

    private static func sorted(_ list: [Torrent]) -> [Torrent] {
        list.sorted { ($0.createdDate ?? .distantPast) > ($1.createdDate ?? .distantPast) }
    }

    /// Mientras haya algo descargándose en TorBox, refresca cada 5 s.
    /// Idempotente: si ya está corriendo, no lo reinicia (reiniciarlo cancelaba refrescos a medio camino).
    func startPolling() {
        if let pollTask, !pollTask.isCancelled { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                guard let self else { return }
                let busy = (self.torrents + self.webDownloads).contains { !$0.isReady && $0.errorText == nil }
                if busy { await self.refresh() }
            }
        }
    }

    func stopPolling() {
        pollTask?.cancel()
        pollTask = nil
    }

    func delete(_ t: Torrent) async {
        do {
            try await api.control(t.kind, id: t.id, operation: "delete")
            if t.kind == .torrent { torrents.removeAll { $0.id == t.id } }
            else { webDownloads.removeAll { $0.id == t.id } }
        } catch { errorMessage = error.localizedDescription }
    }

    /// Borra varios, de a uno (TorBox no tiene borrado en lote). Devuelve cuántos fallaron.
    func deleteMany(_ list: [Torrent]) async -> Int {
        var failed = 0
        for t in list {
            do {
                try await api.control(t.kind, id: t.id, operation: "delete")
                if t.kind == .torrent { torrents.removeAll { $0.id == t.id } }
                else { webDownloads.removeAll { $0.id == t.id } }
            } catch {
                failed += 1
                Diagnostics.log("BULK delete \(t.kind.rawValue)-\(t.id) failed: \(error.localizedDescription)")
            }
        }
        return failed
    }

    /// Activa o quita AirLock en varios. Devuelve cuántos fallaron.
    func airlockMany(_ list: [Torrent], on: Bool) async -> Int {
        var failed = 0
        for t in list where t.airlocked != on {
            if await setAirlock(t, on: on) != nil { failed += 1 }
        }
        return failed
    }

    func rename(_ t: Torrent, to name: String) async -> String? {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return nil }
        do { try await api.rename(t.kind, id: t.id, name: clean); await refresh(); return nil }
        catch { return error.localizedDescription }
    }

    func controlQueued(_ q: QueuedItem, kind: ItemKind, operation: String) async {
        do {
            try await api.controlQueued(id: q.id, operation: operation)
            if kind == .torrent { queuedTorrents.removeAll { $0.id == q.id } } else { queuedWeb.removeAll { $0.id == q.id } }
            await refresh()
        } catch { errorMessage = error.localizedDescription }
    }

    func loadReferral() async {
        referral = try? await api.referralData()
    }

    var currentAPIKey: String? { apiKey }

    /// Activa o quita AirLock. Devuelve el error para mostrarlo junto al control.
    @discardableResult
    func setAirlock(_ t: Torrent, on: Bool) async -> String? {
        do {
            try await api.setAirlock(t.kind, id: t.id, on: on)
            func update(_ list: inout [Torrent]) {
                if let i = list.firstIndex(where: { $0.id == t.id }) { list[i].airlocked = on }
            }
            if t.kind == .torrent { update(&torrents) } else { update(&webDownloads) }
            return nil
        } catch {
            return error.localizedDescription
        }
    }

    func reannounce(_ t: Torrent) async {
        guard t.kind == .torrent else { return }
        do { try await api.control(.torrent, id: t.id, operation: "reannounce"); await refresh() }
        catch { errorMessage = error.localizedDescription }
    }

    // MARK: Entradas externas

    func openAdd(text: String? = nil, file: URL? = nil) {
        incomingText = text
        incomingTorrentFile = file
        showAdd = true
    }

    /// magnet:…            → agregar (se detecta solo)
    /// archivo .torrent     → agregar torrent
    /// tbox://add?url=…     → magnet o enlace web (para usar desde un Atajo en el menú Compartir)
    func handle(url: URL) {
        if url.scheme?.lowercased() == "magnet" {
            openAdd(text: url.absoluteString)
        } else if url.isFileURL, url.pathExtension.lowercased() == "torrent" {
            openAdd(file: url)
        } else if url.scheme?.lowercased() == "tbox",
                  let value = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                    .queryItems?.first(where: { $0.name == "url" || $0.name == "link" || $0.name == "text" })?.value {
            openAdd(text: value.trimmingCharacters(in: .whitespacesAndNewlines))
        }
    }
}
