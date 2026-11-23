import Foundation

// MARK: - Decodificación tolerante
// La API de TorBox no publica esquemas de respuesta; los nombres de campo vienen del SDK oficial
// (torbox-sdk-py). Los tipos se leen de forma flexible (número o texto) para no romper si cambian.

extension KeyedDecodingContainer {
    func flexInt(_ key: Key) -> Int? {
        if let v = try? decodeIfPresent(Int.self, forKey: key) { return v }
        if let v = try? decodeIfPresent(Double.self, forKey: key) { return Int(v) }
        if let s = try? decodeIfPresent(String.self, forKey: key) { return Int(s) ?? Double(s).map { Int($0) } }
        return nil
    }

    func flexInt64(_ key: Key) -> Int64? {
        if let v = try? decodeIfPresent(Int64.self, forKey: key) { return v }
        if let v = try? decodeIfPresent(Double.self, forKey: key) { return Int64(v) }
        if let s = try? decodeIfPresent(String.self, forKey: key) { return Int64(s) ?? Double(s).map { Int64($0) } }
        return nil
    }

    func flexDouble(_ key: Key) -> Double? {
        if let v = try? decodeIfPresent(Double.self, forKey: key) { return v }
        if let s = try? decodeIfPresent(String.self, forKey: key) { return Double(s) }
        return nil
    }

    func flexString(_ key: Key) -> String? {
        if let v = try? decodeIfPresent(String.self, forKey: key) { return v }
        if let v = try? decodeIfPresent(Int.self, forKey: key) { return String(v) }
        if let v = try? decodeIfPresent(Double.self, forKey: key) { return String(v) }
        return nil
    }

    func flexBool(_ key: Key) -> Bool? {
        if let v = try? decodeIfPresent(Bool.self, forKey: key) { return v }
        if let v = try? decodeIfPresent(Int.self, forKey: key) { return v != 0 }
        if let s = try? decodeIfPresent(String.self, forKey: key) { return ["true", "1", "yes"].contains(s.lowercased()) }
        return nil
    }
}

/// Valor JSON genérico, para respuestas cuyo formato no está documentado.
enum JSONValue: Decodable {
    case string(String), number(Double), bool(Bool), object([String: JSONValue]), array([JSONValue]), null

    init(from decoder: Decoder) throws {
        let c = try decoder.singleValueContainer()
        if c.decodeNil() { self = .null }
        else if let v = try? c.decode(Bool.self) { self = .bool(v) }
        else if let v = try? c.decode(Double.self) { self = .number(v) }
        else if let v = try? c.decode(String.self) { self = .string(v) }
        else if let v = try? c.decode([String: JSONValue].self) { self = .object(v) }
        else if let v = try? c.decode([JSONValue].self) { self = .array(v) }
        else { self = .null }
    }

    var stringValue: String? {
        if case .string(let s) = self { return s }
        return nil
    }

    var intValue: Int? {
        switch self {
        case .number(let d): return Int(d)
        case .string(let s): return Int(s)
        default: return nil
        }
    }

    subscript(key: String) -> JSONValue? {
        if case .object(let o) = self { return o[key] }
        return nil
    }
}

/// Todas las respuestas de TorBox vienen envueltas en { success, error, detail, data }.
struct APIEnvelope<T: Decodable>: Decodable {
    let success: Bool?
    let error: String?
    let detail: String?
    let data: T?

    enum CodingKeys: String, CodingKey { case success, error, detail, data }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = c.flexBool(.success)
        error = c.flexString(.error)
        detail = c.flexString(.detail)
        data = try c.decodeIfPresent(T.self, forKey: .data)
    }
}

// MARK: - Torrents

struct TorrentFile: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let shortName: String?
    let size: Int64
    let mimetype: String?

    enum CodingKeys: String, CodingKey { case id, name, short_name, size, mimetype }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexInt(.id) ?? 0
        name = c.flexString(.name) ?? "archivo"
        shortName = c.flexString(.short_name)
        size = c.flexInt64(.size) ?? 0
        mimetype = c.flexString(.mimetype)
    }

    /// Nombre sin la carpeta del torrent.
    var displayName: String {
        if let s = shortName, !s.isEmpty { return s }
        return (name as NSString).lastPathComponent
    }

    var fileExtension: String { (displayName as NSString).pathExtension.lowercased() }

    var isVideo: Bool {
        if let m = mimetype, m.hasPrefix("video/") { return true }
        return ["mkv", "mp4", "m4v", "mov", "avi", "ts", "m2ts", "webm", "wmv", "flv", "mpg", "mpeg"].contains(fileExtension)
    }

    var isImage: Bool {
        if let m = mimetype, m.hasPrefix("image/") { return true }
        return ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp"].contains(fileExtension)
    }

    /// Se puede guardar en la app Fotos.
    var canSaveToPhotos: Bool { MediaKind.canSaveToPhotos(fileExtension) }

    /// Formatos que el reproductor nativo de iOS (AVPlayer) abre sin ayuda.
    var isNativelyPlayable: Bool {
        ["mp4", "m4v", "mov", "m3u8", "mp3", "m4a", "aac", "wav"].contains(fileExtension)
    }
}

/// Tipo de descarga en TorBox. Los web downloads usan casi los mismos campos que los torrents.
enum ItemKind: String, Hashable, CaseIterable {
    case torrent, web

    var listPath: String { self == .torrent ? "torrents/mylist" : "webdl/mylist" }
    var controlPath: String { self == .torrent ? "torrents/controltorrent" : "webdl/controlwebdownload" }
    var controlIDKey: String { self == .torrent ? "torrent_id" : "webdl_id" }
    var requestPath: String { self == .torrent ? "torrents/requestdl" : "webdl/requestdl" }
    var requestIDKey: String { self == .torrent ? "torrent_id" : "web_id" }
    var editPath: String { self == .torrent ? "torrents/edittorrent" : "webdl/editwebdownload" }
    var title: String { self == .torrent ? "Torrents" : "Web" }
}

/// Descarga que TorBox dejó en cola por falta de cupos. Aún no tiene ID de torrent ni de web download.
struct QueuedItem: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let createdAt: String?

    enum CodingKeys: String, CodingKey { case id, name, created_at, magnet, hash }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexInt(.id) ?? 0
        var n = c.flexString(.name)
        if n == nil || n?.isEmpty == true, let m = c.flexString(.magnet) {
            n = LinkParser.magnetName(m)
        }
        name = n ?? c.flexString(.hash) ?? L("Sin nombre")
        createdAt = c.flexString(.created_at)
    }
}

/// Código de referido propio del usuario, leído de forma tolerante (la API no documenta los campos).
struct ReferralInfo {
    let code: String?
    let count: Int?

    init(_ json: JSONValue?) {
        var code: String?
        var count: Int?
        func walk(_ v: JSONValue, key: String) {
            switch v {
            case .object(let o): for (k, x) in o { walk(x, key: k.lowercased()) }
            case .array(let a): if key.contains("referr") && count == nil { count = a.count }
            case .string(let s):
                if code == nil, key.contains("code") || key == "referral", s.count >= 6, !s.contains(" ") { code = s }
            case .number(let d):
                if count == nil, key.contains("count") || key.contains("referred") || key.contains("referrals") { count = Int(d) }
            default: break
            }
        }
        if let json { walk(json, key: "") }
        self.code = code
        self.count = count
    }

    var shareURL: URL? {
        code.flatMap { URL(string: "https://torbox.app/subscription?referral=\($0)") }
    }
}

/// Referencia para navegación: los IDs de torrents y de web downloads pueden coincidir.
struct ItemRef: Hashable {
    let kind: ItemKind
    let id: Int
}

/// Un torrent o un web download de TorBox.
struct Torrent: Decodable, Identifiable, Hashable {
    var kind: ItemKind = .torrent
    let id: Int
    let hash: String?
    let name: String
    let size: Int64
    let progress: Double          // 0...1
    let downloadSpeed: Int64
    let uploadSpeed: Int64
    let eta: Int?
    let seeds: Int?
    let peers: Int?
    let downloadState: String
    let downloadFinished: Bool
    let downloadPresent: Bool
    let active: Bool
    let createdAt: String?
    let errorText: String?
    let files: [TorrentFile]
    /// En AirLock: TorBox no lo borra en la purga de 30 días sin actividad (planes pagados).
    var airlocked: Bool

    var ref: ItemRef { ItemRef(kind: kind, id: id) }

    enum CodingKeys: String, CodingKey {
        case id, hash, name, size, progress, eta, seeds, peers, active, files, error, airlocked
        case download_speed, upload_speed, download_state, download_finished, download_present, created_at
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = c.flexInt(.id) ?? 0
        hash = c.flexString(.hash)
        name = c.flexString(.name) ?? L("Sin nombre")
        size = c.flexInt64(.size) ?? 0
        let p = c.flexDouble(.progress) ?? 0
        progress = p > 1 ? p / 100 : p
        downloadSpeed = c.flexInt64(.download_speed) ?? 0
        uploadSpeed = c.flexInt64(.upload_speed) ?? 0
        eta = c.flexInt(.eta)
        seeds = c.flexInt(.seeds)
        peers = c.flexInt(.peers)
        downloadState = c.flexString(.download_state) ?? "desconocido"
        downloadFinished = c.flexBool(.download_finished) ?? false
        downloadPresent = c.flexBool(.download_present) ?? false
        active = c.flexBool(.active) ?? false
        createdAt = c.flexString(.created_at)
        errorText = c.flexString(.error)
        airlocked = c.flexBool(.airlocked) ?? false
        files = (try? c.decodeIfPresent([TorrentFile].self, forKey: .files)) ?? []
    }

    var isReady: Bool { downloadPresent || downloadFinished }

    /// Motivo de la falla. TorBox a veces lo manda en "error" y a veces dentro del estado
    /// (las descargas web fallidas traen el mensaje de yt-dlp en download_state).
    var failureText: String? {
        if let e = errorText?.trimmingCharacters(in: .whitespacesAndNewlines), !e.isEmpty { return e }
        guard !isReady else { return nil }
        let s = downloadState.trimmingCharacters(in: .whitespacesAndNewlines)
        let l = s.lowercased()
        guard l.contains("error") || l.hasPrefix("failed") else { return nil }
        if let r = s.range(of: "ERROR:", options: .caseInsensitive) {
            let msg = s[r.upperBound...].trimmingCharacters(in: .whitespaces)
            if !msg.isEmpty { return msg }
        }
        return l == "error" ? L("TorBox no pudo completar la descarga.") : s
    }

    var createdDate: Date? { createdAt.flatMap(TorBoxDate.parse) }

    var sortedFiles: [TorrentFile] {
        files.sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
    }
}

// MARK: - Usuario

struct UserInfo: Decodable {
    let email: String?
    let plan: Int?
    let premiumExpiresAt: String?

    enum CodingKeys: String, CodingKey { case email, plan, premium_expires_at }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        email = c.flexString(.email)
        plan = c.flexInt(.plan)
        premiumExpiresAt = c.flexString(.premium_expires_at)
    }

    /// Números de plan según el cliente YATBA (0 Free, 1 Essential, 2 Pro, 3 Standard).
    /// Solo "2 = Pro" figura en la documentación oficial de TorBox.
    var planName: String {
        switch plan {
        case 0: return "Free"
        case 1: return "Essential"
        case 2: return "Pro"
        case 3: return "Standard"
        case .some(let p): return L("Plan") + " \(p)"
        case .none: return "—"
        }
    }

    var isPro: Bool { plan == 2 }
    var isFree: Bool { plan == 0 }
}

// MARK: - Login por código de dispositivo (verificado contra la API el 15-nov-2026)

struct DeviceStart: Decodable {
    let deviceCode: String
    let code: String
    let interval: Int
    let expiresIn: Int?
    let verificationURL: String?
    let verificationURLComplete: String?
    let friendlyVerificationURL: String?

    enum CodingKeys: String, CodingKey {
        case device_code, code, interval, expires_in, verification_url, verification_url_complete, friendly_verification_url
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        deviceCode = c.flexString(.device_code) ?? ""
        code = c.flexString(.code) ?? ""
        interval = max(c.flexInt(.interval) ?? 5, 2)
        expiresIn = c.flexInt(.expires_in)
        verificationURL = c.flexString(.verification_url)
        verificationURLComplete = c.flexString(.verification_url_complete)
        friendlyVerificationURL = c.flexString(.friendly_verification_url)
    }
}

/// Resultado de agregar algo a TorBox.
struct CreateResult: Equatable {
    var message: String?
    var itemID: Int?
    var queuedID: Int?
    var async = false
}

enum DeviceTokenResult {
    case pending, expired, alreadyUsed, token(String), failed(String)
}

// MARK: - Formato

enum Fmt {
    static func bytes(_ b: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: b, countStyle: .file)
    }

    static func speed(_ b: Int64) -> String { bytes(b) + "/s" }

    static func eta(_ seconds: Int?) -> String? {
        guard let s = seconds, s > 0, s < 60 * 60 * 24 * 30 else { return nil }
        let f = DateComponentsFormatter()
        f.allowedUnits = s >= 3600 ? [.hour, .minute] : [.minute, .second]
        f.unitsStyle = .abbreviated
        return f.string(from: TimeInterval(s))
    }

    /// Traduce los estados más comunes de TorBox; lo demás se muestra tal cual.
    static func state(_ raw: String) -> String {
        let r = raw.lowercased()
        if r.hasPrefix("stalled") { return L("Detenido (sin seeds)") }
        switch r {
        case "downloading": return L("Descargando")
        case "uploading": return L("Listo · subiendo")
        case "completed": return L("Completado")
        case "cached": return L("En caché")
        case "paused": return L("Pausado")
        case "metadl": return L("Obteniendo metadatos")
        case "checkingresumedata", "checking": return L("Verificando")
        case "queued", "queuedup": return L("En cola")
        case "error": return L("Error")
        default:
            // Estados desconocidos: nunca un texto largo en la etiqueta.
            let s = raw.prefix(1).uppercased() + raw.dropFirst()
            return s.count > 24 ? String(s.prefix(22)) + "…" : s
        }
    }
}


// MARK: - Sitios compatibles (GET /webdl/hosters, verificado el 15-nov-2026)

struct Hoster: Decodable, Identifiable {
    let id: Int
    let name: String
    let domains: [String]
    let status: Bool
    let type: String?
    let note: String?
    let nsfw: Bool
    let dailyLinkLimit: Int?
    let dailyLinkUsed: Int?

    enum CodingKeys: String, CodingKey {
        case id, name, domains, status, type, note, nsfw, daily_link_limit, daily_link_used
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = c.flexString(.name) ?? "?"
        id = c.flexInt(.id) ?? name.hashValue
        domains = (try? c.decodeIfPresent([String].self, forKey: .domains)) ?? []
        status = c.flexBool(.status) ?? false
        type = c.flexString(.type)
        note = c.flexString(.note)
        nsfw = c.flexBool(.nsfw) ?? false
        dailyLinkLimit = c.flexInt(.daily_link_limit)
        dailyLinkUsed = c.flexInt(.daily_link_used)
    }

    func matches(host: String) -> Bool {
        let h = host.lowercased()
        return domains.contains { h == $0.lowercased() || h.hasSuffix("." + $0.lowercased()) }
    }
}

enum MediaKind {
    static let photoExtensions: Set<String> = ["jpg", "jpeg", "png", "heic", "heif", "gif", "webp"]
    static let videoExtensions: Set<String> = ["mp4", "m4v", "mov"]

    static func canSaveToPhotos(_ ext: String) -> Bool {
        photoExtensions.contains(ext.lowercased()) || videoExtensions.contains(ext.lowercased())
    }

    static func isPhoto(_ ext: String) -> Bool { photoExtensions.contains(ext.lowercased()) }
}


// MARK: - Interpretar lo que el usuario pega

enum AddKind: String { case magnet, web }

struct ParsedLink: Hashable {
    let kind: AddKind
    let value: String      // lo que se envía a TorBox (ya normalizado)
    let original: String   // lo que pegó el usuario

    var displayName: String {
        if kind == .magnet {
            // En los magnets los espacios suelen venir como "+", que URLComponents no convierte.
            if let dn = URLComponents(string: value)?.queryItems?.first(where: { $0.name == "dn" })?.value, !dn.isEmpty {
                return dn.replacingOccurrences(of: "+", with: " ")
            }
            return "magnet"
        }
        return URL(string: value)?.host ?? value
    }
}

enum LinkParser {
    /// Nombre legible de un magnet (parámetro dn), si lo trae.
    static func magnetName(_ magnet: String) -> String? {
        guard let dn = URLComponents(string: magnet)?.queryItems?.first(where: { $0.name == "dn" })?.value,
              !dn.isEmpty else { return nil }
        return dn.replacingOccurrences(of: "+", with: " ")
    }

    /// Separa por espacios/saltos de línea y reconoce magnets y enlaces http(s).
    /// Devuelve también los fragmentos que no se reconocieron.
    static func parse(_ text: String) -> (links: [ParsedLink], ignored: [String]) {
        var links: [ParsedLink] = []
        var ignored: [String] = []
        var seen = Set<String>()
        for raw in text.components(separatedBy: .whitespacesAndNewlines) {
            let token = raw.trimmingCharacters(in: CharacterSet(charactersIn: "<>\"'"))
            guard !token.isEmpty else { continue }
            let lower = token.lowercased()
            let link: ParsedLink?
            if lower.hasPrefix("magnet:?") {
                link = ParsedLink(kind: .magnet, value: token, original: token)
            } else if lower.hasPrefix("http://") || lower.hasPrefix("https://") {
                link = ParsedLink(kind: .web, value: normalizeWeb(token), original: token)
            } else {
                link = nil
            }
            if let link {
                if seen.insert(link.value).inserted { links.append(link) }
            } else {
                ignored.append(token)
            }
        }
        return (links, ignored)
    }

    /// Corrige enlaces conocidos que TorBox rechaza. Hoy: Scribd (enlaces internos con doc=ID).
    static func normalizeWeb(_ link: String) -> String {
        guard let comps = URLComponents(string: link), let host = comps.host?.lowercased(),
              host == "scribd.com" || host.hasSuffix(".scribd.com") else { return link }
        if let doc = comps.queryItems?.first(where: { $0.name == "doc" })?.value, Int(doc) != nil {
            return "https://www.scribd.com/document/\(doc)"
        }
        let parts = comps.path.split(separator: "/").map(String.init)
        if let i = parts.firstIndex(where: { ["document", "doc"].contains($0) }), i + 1 < parts.count,
           Int(parts[i + 1]) != nil {
            return "https://www.scribd.com/document/\(parts[i + 1])"
        }
        return link
    }
}

// MARK: - Detectar lo que terminó en TorBox entre una revisión y otra

/// Recuerda qué ítems estaban en curso; cuando uno pasa a listo, lo informa una sola vez.
/// La primera vez solo memoriza (no avisa de lo que ya estaba listo antes).
struct ReadyTracker {
    private let defaults: UserDefaults
    private let key: String

    init(defaults: UserDefaults = .standard, key: String = "ready.pending") {
        self.defaults = defaults
        self.key = key
    }

    mutating func process(_ items: [Torrent], kinds: Set<ItemKind>) -> [Torrent] {
        let stored = defaults.dictionary(forKey: key) as? [String: String]
        var pending = stored ?? [:]
        var ready: [Torrent] = []
        for kind in kinds {
            let prefix = kind == .torrent ? "t" : "w"
            let ofKind = items.filter { $0.kind == kind }
            let currentKeys = Set(ofKind.map { prefix + String($0.id) })
            // los borrados dejan de esperarse
            for k in pending.keys where k.hasPrefix(prefix) && !currentKeys.contains(k) { pending.removeValue(forKey: k) }
            for item in ofKind {
                let k = prefix + String(item.id)
                if item.isReady {
                    if pending.removeValue(forKey: k) != nil, stored != nil { ready.append(item) }
                } else if item.failureText == nil {
                    pending[k] = item.name
                }
            }
        }
        defaults.set(pending, forKey: key)
        return ready
    }
}

/// Fechas de TorBox en cualquiera de sus formatos: con o sin decimales (de cualquier largo),
/// con "Z", "+00:00" o sin zona (se asume UTC), con "T" o espacio, o como número Unix.
enum TorBoxDate {
    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()
    private static var cache: [String: Date] = [:]
    private static let lock = NSLock()

    static func parse(_ raw: String) -> Date? {
        lock.lock(); defer { lock.unlock() }
        if let d = cache[raw] { return d }
        let d = compute(raw)
        if let d { cache[raw] = d }
        return d
    }

    private static func compute(_ raw: String) -> Date? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        if let n = Double(s) { return Date(timeIntervalSince1970: n > 1e12 ? n / 1000 : n) }
        var t = s.replacingOccurrences(of: " ", with: "T")
        // Quitar los decimales de los segundos, tengan los dígitos que tengan.
        if let r = t.range(of: #"\.\d+"#, options: .regularExpression) { t.removeSubrange(r) }
        // Sin zona horaria: se asume UTC.
        if t.range(of: #"(Z|[+-]\d{2}:?\d{2})$"#, options: .regularExpression) == nil { t += "Z" }
        return iso.date(from: t)
    }
}
