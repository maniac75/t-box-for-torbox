import XCTest

/// Verifica que la app siga leyendo bien las respuestas de TorBox.
/// Los ejemplos imitan los formatos documentados en el SDK oficial y los observados en la API real.
final class DecodingTests: XCTestCase {
    private let decoder = JSONDecoder()

    func testTorrentList() throws {
        let json = """
        {"success":true,"error":null,"detail":"ok","data":[
          {"id":123,"hash":"abc","name":"Pelicula 2024","size":4500000000,"progress":0.42,
           "download_speed":5000000,"upload_speed":0,"eta":600,"seeds":10,"peers":3,
           "download_state":"downloading","download_finished":false,"download_present":false,"active":true,
           "created_at":"2026-11-14T10:00:00Z",
           "files":[{"id":0,"name":"Pelicula 2024/movie.mkv","short_name":"movie.mkv","size":4400000000,"mimetype":"video/x-matroska"}]},
          {"id":"124","name":"X","size":"10","progress":"100","download_finished":1,"files":null}
        ]}
        """
        let env = try decoder.decode(APIEnvelope<[Torrent]>.self, from: Data(json.utf8))
        let list = try XCTUnwrap(env.data)
        XCTAssertEqual(list.count, 2)
        XCTAssertEqual(list[0].id, 123)
        XCTAssertEqual(list[0].progress, 0.42, accuracy: 0.0001)
        XCTAssertFalse(list[0].isReady)
        XCTAssertNotNil(list[0].createdDate)
        XCTAssertEqual(list[0].files.first?.displayName, "movie.mkv")
        XCTAssertTrue(list[0].files.first?.isVideo == true)
        XCTAssertFalse(list[0].files.first?.isNativelyPlayable == true)
        // Tipos flexibles: id y tamaño como texto, progreso 0-100
        XCTAssertEqual(list[1].id, 124)
        XCTAssertEqual(list[1].size, 10)
        XCTAssertEqual(list[1].progress, 1.0, accuracy: 0.0001)
        XCTAssertTrue(list[1].isReady)
        XCTAssertTrue(list[1].files.isEmpty)
    }

    func testWebDownloadWithErrorAndPhoto() throws {
        let json = """
        {"success":true,"data":[{"id":5,"name":"foto.jpg","size":100,"progress":0,"download_finished":false,
          "download_present":false,"error":"Host down","files":[{"id":0,"name":"foto.jpg","size":100,"mimetype":"image/jpeg"}]}]}
        """
        var list = try XCTUnwrap(decoder.decode(APIEnvelope<[Torrent]>.self, from: Data(json.utf8)).data)
        list[0].kind = .web
        XCTAssertEqual(list[0].ref, ItemRef(kind: .web, id: 5))
        XCTAssertEqual(list[0].errorText, "Host down")
        XCTAssertTrue(list[0].files[0].isImage)
        XCTAssertTrue(list[0].files[0].canSaveToPhotos)
    }

    /// Las descargas web fallidas traen el error de yt-dlp en download_state y "error" vacío.
    func testFailureInDownloadState() throws {
        let json = """
        {"success":true,"data":[
          {"id":7,"name":"Video","size":0,"progress":0,"download_finished":false,"download_present":false,
           "download_state":"[youtube] abc: ERROR: unable to download video data: HTTP Error 403: Forbidden","files":[]},
          {"id":8,"name":"Otro","size":0,"progress":0.3,"download_state":"downloading","files":[]}
        ]}
        """
        let list = try XCTUnwrap(decoder.decode(APIEnvelope<[Torrent]>.self, from: Data(json.utf8)).data)
        XCTAssertEqual(list[0].failureText, "unable to download video data: HTTP Error 403: Forbidden")
        XCTAssertNil(list[1].failureText)
    }

    func testAirlockedField() throws {
        let on = try JSONDecoder().decode(Torrent.self, from: Data(#"{"id":1,"name":"a","airlocked":true,"download_present":true}"#.utf8))
        let off = try JSONDecoder().decode(Torrent.self, from: Data(#"{"id":2,"name":"b"}"#.utf8))
        XCTAssertTrue(on.airlocked)
        XCTAssertFalse(off.airlocked)
        XCTAssertEqual(ItemKind.web.editPath, "webdl/editwebdownload")
    }

    func testQueuedAndReferral() throws {
        let q = try JSONDecoder().decode([QueuedItem].self, from: Data(#"[{"id":7,"magnet":"magnet:?xt=urn:btih:abc&dn=Big+Buck+Bunny"}]"#.utf8))
        XCTAssertEqual(q.first?.name, "Big Buck Bunny")
        let json = try JSONDecoder().decode(JSONValue.self, from: Data(#"{"referral_code":"7b4a584a-00a5","referred_accounts":3}"#.utf8))
        let r = ReferralInfo(json)
        XCTAssertEqual(r.code, "7b4a584a-00a5")
        XCTAssertEqual(r.count, 3)
        XCTAssertNil(ReferralInfo(nil).shareURL)
    }

    func testFailureEnvelope() throws {
        let json = #"{"success":false,"error":"ITEM_NOT_FOUND","detail":"Expired","data":null}"#
        let env = try decoder.decode(APIEnvelope<JSONValue>.self, from: Data(json.utf8))
        XCTAssertEqual(env.success, false)
        XCTAssertEqual(env.error, "ITEM_NOT_FOUND")
    }

    func testDeviceStart() throws {
        // Forma observada en la API real el 15-nov-2026
        let json = """
        {"success":true,"error":null,"detail":"ok","data":{"device_code":"dc","code":"AB12CD","interval":5,
         "expires_in":600,"expires_at":"2026-11-15T12:28:06Z","verification_url":"https://torbox.app/oauth/device?app=TBox",
         "verification_url_complete":"https://torbox.app/oauth/device?app=TBox&code=AB12CD","friendly_verification_url":"https://tor.box/link"}}
        """
        let start = try XCTUnwrap(decoder.decode(APIEnvelope<DeviceStart>.self, from: Data(json.utf8)).data)
        XCTAssertEqual(start.code, "AB12CD")
        XCTAssertEqual(start.interval, 5)
        XCTAssertNotNil(start.verificationURLComplete)
    }

    func testDeviceTokenShape() throws {
        // YATBA documenta {access_token, token_type}
        let json = #"{"success":true,"data":{"access_token":"KEY","token_type":"bearer"}}"#
        let env = try decoder.decode(APIEnvelope<JSONValue>.self, from: Data(json.utf8))
        XCTAssertEqual(env.data?["access_token"]?.stringValue, "KEY")
    }

    func testUserPlans() throws {
        func plan(_ n: Int) throws -> UserInfo {
            try XCTUnwrap(decoder.decode(APIEnvelope<UserInfo>.self,
                                         from: Data(#"{"success":true,"data":{"email":"a@b.c","plan":\#(n)}}"#.utf8)).data)
        }
        XCTAssertTrue(try plan(0).isFree)
        XCTAssertTrue(try plan(2).isPro)
        XCTAssertEqual(try plan(3).planName, "Standard")
    }

    func testHosterMatching() throws {
        let json = """
        {"success":true,"data":[
          {"id":1,"name":"Instagram","domains":["instagram.com"],"status":true,"type":"stream","note":"Does not show download status.","nsfw":false,"daily_link_limit":100,"daily_link_used":0},
          {"id":2,"name":"Twitter","domains":["twitter.com","x.com","t.co"],"status":true,"type":"stream","note":null,"nsfw":false,"daily_link_limit":100,"daily_link_used":3}
        ]}
        """
        let hosters = try XCTUnwrap(decoder.decode(APIEnvelope<[Hoster]>.self, from: Data(json.utf8)).data)
        XCTAssertTrue(hosters[0].matches(host: "www.instagram.com"))
        XCTAssertTrue(hosters[1].matches(host: "x.com"))
        XCTAssertFalse(hosters[1].matches(host: "notx.com"))
    }

    func testFormEncoding() {
        let body = String(decoding: TorBoxAPI.formURLEncoded([("link", "https://x.com/a?b=1&c=2"), ("password", "p ñ")]), as: UTF8.self)
        XCTAssertEqual(body, "link=https%3A%2F%2Fx.com%2Fa%3Fb%3D1%26c%3D2&password=p%20%C3%B1")
    }

    func testRedaction() {
        let key = "abcdef1234567890"
        let raw = "GET /requestdl?token=\(key)&torrent_id=1 Authorization: Bearer \(key) other \(key)"
        let out = Diagnostics.redact(raw, secrets: [key])
        XCTAssertFalse(out.contains(key))
        XCTAssertTrue(out.contains("token=***"))
    }

    func testCancellationIsNotAnError() {
        XCTAssertTrue(TorBoxAPI.isCancellation(URLError(.cancelled)))
        XCTAssertTrue(TorBoxAPI.isCancellation(CancellationError()))
        XCTAssertFalse(TorBoxAPI.isCancellation(URLError(.timedOut)))
    }

    func testLinkParserTorrentFileLink() {
        let r = LinkParser.parse("https://example.org/dl/My%20Show.S01E01.torrent\nhttps://example.org/page")
        XCTAssertEqual(r.links.map(\.kind), [.torrentURL, .web])
        XCTAssertEqual(r.links[0].displayName, "My Show.S01E01.torrent")
        XCTAssertTrue(r.links[0].isTorrent)
    }

    func testLinkParserMixed() {
        let text = """
        magnet:?xt=urn:btih:dd8255ecdc7ca55fb0bbf81323d87062db1f6d1c&dn=Big+Buck+Bunny
        https://www.instagram.com/p/abc/   https://www.instagram.com/p/abc/
        hola
        """
        let r = LinkParser.parse(text)
        XCTAssertEqual(r.links.count, 2)   // el enlace repetido cuenta una vez
        XCTAssertEqual(r.links[0].kind, .magnet)
        XCTAssertEqual(r.links[0].displayName, "Big Buck Bunny")
        XCTAssertEqual(r.links[1].kind, .web)
        XCTAssertEqual(r.ignored, ["hola"])
    }

    func testScribdNormalization() {
        XCTAssertEqual(LinkParser.normalizeWeb("https://es.scribd.com/doc/x?doc=766311884&metadata=%7B%7D"),
                       "https://www.scribd.com/document/766311884")
        XCTAssertEqual(LinkParser.normalizeWeb("https://www.scribd.com/document/123456/Some-Title"),
                       "https://www.scribd.com/document/123456")
        XCTAssertEqual(LinkParser.normalizeWeb("https://mega.nz/file/x"), "https://mega.nz/file/x")
    }

    func testReadyTracker() throws {
        let suite = "tbox.tests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        func item(_ id: Int, ready: Bool) throws -> Torrent {
            let json = #"{"id":\#(id),"name":"n\#(id)","download_finished":\#(ready),"download_present":\#(ready)}"#
            return try JSONDecoder().decode(Torrent.self, from: Data(json.utf8))
        }
        var tracker = ReadyTracker(defaults: defaults, key: "k")
        // Primera pasada: solo memoriza
        XCTAssertTrue(tracker.process([try item(1, ready: false), try item(2, ready: true)], kinds: [.torrent]).isEmpty)
        // El 1 termina: avisa una vez
        XCTAssertEqual(tracker.process([try item(1, ready: true), try item(2, ready: true)], kinds: [.torrent]).map(\.id), [1])
        XCTAssertTrue(tracker.process([try item(1, ready: true)], kinds: [.torrent]).isEmpty)
    }

    func testCreateResultID() throws {
        let env = try decoder.decode(APIEnvelope<JSONValue>.self,
                                     from: Data(#"{"success":true,"detail":"Found Cached","data":{"torrent_id":42,"hash":"x"}}"#.utf8))
        XCTAssertEqual(env.data?["torrent_id"]?.intValue, 42)
    }

    func testReferralURL() {
        XCTAssertEqual(AppConfig.referralURL.absoluteString,
                       "https://torbox.app/subscription?referral=7b4a584a-00a5-430e-aa31-809aa4934cb0")
    }

    func testTorBoxDateFormats() {
        let ref = Date(timeIntervalSince1970: 1_794_783_762)   // 2026-11-15T23:02:42Z
        for s in ["2026-11-15T23:02:42Z", "2026-11-15T23:02:42.123Z", "2026-11-15T23:02:42.123456Z",
                  "2026-11-15T23:02:42+00:00", "2026-11-15T23:02:42.5+00:00", "2026-11-15 23:02:42",
                  "2026-11-15T23:02:42", "1794783762"] {
            XCTAssertEqual(TorBoxDate.parse(s), ref, s)
        }
        XCTAssertNil(TorBoxDate.parse("not a date"))
    }

    func testVersionCompare() {
        XCTAssertTrue(UpdateChecker.isNewer("0.3.3", than: "0.3.2"))
        XCTAssertTrue(UpdateChecker.isNewer("0.3.10", than: "0.3.9"))
        XCTAssertTrue(UpdateChecker.isNewer("1.0", than: "0.9.9"))
        XCTAssertFalse(UpdateChecker.isNewer("0.3.2", than: "0.3.2"))
        XCTAssertFalse(UpdateChecker.isNewer("0.3.1", than: "0.3.2"))
    }
}
