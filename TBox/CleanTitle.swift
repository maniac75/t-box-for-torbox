import Foundation

/// Convierte nombres de release en títulos legibles:
/// "The.Office.US.S03E04.1080p.WEB-DL.x264-GRUPO.mkv" → "The Office US S03E04",
/// "Dune.Part.Two.2024.2160p.UHD.BluRay" → "Dune Part Two (2024)".
/// Si no reconoce nada, devuelve el nombre casi intacto (sin extensión). Nunca devuelve algo vacío.
enum CleanTitle {
    private static let extensions: Set<String> = ["mkv", "mp4", "avi", "mov", "m4v", "wmv", "ts", "webm",
                                                   "zip", "rar", "7z", "iso", "srt", "flac", "mp3"]

    private static let quality = "(2160p|1080p|720p|576p|480p|4k|uhd|web[ -]?dl|webrip|web|blu ?ray|bdrip|brrip|bdremux|hdrip|dvdrip|dvd|hdtv|remux|x264|x265|h ?26[45]|hevc|avc|10bit|hdr10\\+?|hdr|dv|dovi|atmos|ddp?[ ]?[257] ?[01]|aac|ac3|dts(?:-hd)?|truehd|proper|repack|multi|dual|latino|castellano|vose|subs?|amzn|nf|dsnp|hmax|atvp|internal|limited|extended|unrated|imax)"

    private static func regex(_ pattern: String) -> NSRegularExpression {
        // Los patrones son fijos: si uno estuviera mal, es un error de programación.
        try! NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
    }

    private static let leadingTags = regex("^\\s*(\\[[^\\]]*\\]\\s*)+")
    private static let trailingTag = regex("\\s*\\[[^\\]]*\\]\\s*$")
    private static let separators = regex("[._]+")
    private static let spaces = regex("\\s+")
    private static let episode = regex("\\bS(\\d{1,2}) ?E(\\d{1,3})(?:[ -]?E\\d{1,3})*\\b")
    private static let altEpisode = regex("\\b(\\d{1,2})x(\\d{2,3})\\b")
    private static let seasonPack = regex("\\b(?:S(\\d{1,2})|Season (\\d{1,2})|Temporada (\\d{1,2}))\\b")
    private static let year = regex("(?<!\\d)(19[2-9]\\d|20[0-4]\\d)(?!\\d)")
    private static let qualityToken = regex("\\b" + quality + "\\b")
    private static let resolution = regex("\\b\\d{3,4}p\\b")
    private static let trailingJunk = regex("[\\s\\-–(\\[{]+$")
    private static let emptyParens = regex("\\(\\s*\\)")

    /// Con caché: las filas de la biblioteca lo piden en cada redibujo. Solo desde el hilo principal.
    private static var cache: [String: String] = [:]
    static func cached(_ raw: String) -> String {
        if let hit = cache[raw] { return hit }
        let clean = make(raw)
        if cache.count > 2000 { cache.removeAll() }
        cache[raw] = clean
        return clean
    }

    static func make(_ raw: String) -> String {
        var s = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        // Extensión de archivo conocida.
        if let dot = s.lastIndex(of: "."), s.distance(from: dot, to: s.endIndex) <= 5,
           extensions.contains(String(s[s.index(after: dot)...]).lowercased()) {
            s = String(s[..<dot])
        }
        s = replace(leadingTags, in: s, with: "")
        s = replace(trailingTag, in: s, with: "")

        // Solo los nombres "con puntos" (estilo release) cambian puntos y guiones bajos por espacios.
        let separatorCount = s.filter { $0 == "." || $0 == "_" }.count
        let dotted = separatorCount > s.filter { $0 == " " }.count
        if dotted { s = replace(separators, in: s, with: " ") }
        s = replace(spaces, in: s, with: " ").trimmingCharacters(in: .whitespaces)

        var title: String
        var suffix = ""
        if let m = first(episode, in: s) {
            title = prefix(s, before: m)
            suffix = String(format: " S%02dE%02d", int(m, 1, in: s), int(m, 2, in: s))
        } else if let m = first(altEpisode, in: s) {
            title = prefix(s, before: m)
            suffix = String(format: " S%02dE%02d", int(m, 1, in: s), int(m, 2, in: s))
        } else if let m = first(seasonPack, in: s) {
            title = prefix(s, before: m)
            let n = (1...3).map { int(m, $0, in: s) }.first { $0 > 0 } ?? 0
            suffix = String(format: " S%02d", n)
        } else if let m = year.matches(in: s, range: NSRange(s.startIndex..., in: s)).last(where: { $0.range.location > 0 }) {
            // El último año: "2001 A Space Odyssey 1968" → 1968; "Blade Runner 2049 2017" → 2017.
            title = prefix(s, before: m)
            suffix = " (\(group(m, 1, in: s)))"
        } else {
            title = s
            let looksLikeRelease = dotted || first(resolution, in: s) != nil
            if looksLikeRelease, let m = first(qualityToken, in: s), m.range.location > 0 {
                title = prefix(s, before: m)
            }
        }

        title = replace(trailingJunk, in: title, with: "")
        title = replace(emptyParens, in: title, with: "").trimmingCharacters(in: .whitespaces)
        guard title.count >= 2 else { return s.isEmpty ? raw : s }
        return title + suffix
    }

    // MARK: Ayudas

    private static func replace(_ re: NSRegularExpression, in s: String, with t: String) -> String {
        re.stringByReplacingMatches(in: s, range: NSRange(s.startIndex..., in: s), withTemplate: t)
    }

    private static func first(_ re: NSRegularExpression, in s: String) -> NSTextCheckingResult? {
        re.firstMatch(in: s, range: NSRange(s.startIndex..., in: s))
    }

    private static func prefix(_ s: String, before m: NSTextCheckingResult) -> String {
        guard let r = Range(m.range, in: s) else { return s }
        return String(s[..<r.lowerBound])
    }

    private static func group(_ m: NSTextCheckingResult, _ i: Int, in s: String) -> String {
        guard i < m.numberOfRanges, let r = Range(m.range(at: i), in: s) else { return "" }
        return String(s[r])
    }

    private static func int(_ m: NSTextCheckingResult, _ i: Int, in s: String) -> Int {
        Int(group(m, i, in: s)) ?? 0
    }
}
