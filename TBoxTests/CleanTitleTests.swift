import XCTest

final class CleanTitleTests: XCTestCase {
    private let cases: [(String, String)] = [
        ("The.Office.US.S03E04.1080p.WEB-DL.x264-GRUPO.mkv", "The Office US S03E04"),
        ("Dune.Part.Two.2024.2160p.UHD.BluRay.REMUX.HDR.DV.TrueHD.Atmos-FGT", "Dune Part Two (2024)"),
        ("[SubsPlease] Frieren - 12 (1080p) [ABCD1234].mkv", "Frieren - 12"),
        ("Breaking Bad Season 1 Complete 720p", "Breaking Bad S01"),
        ("Severance.S02.2160p.ATVP.WEB-DL.DDP5.1.HEVC-NTb", "Severance S02"),
        ("2001.A.Space.Odyssey.1968.1080p.BluRay", "2001 A Space Odyssey (1968)"),
        ("Blade.Runner.2049.2017.1080p", "Blade Runner 2049 (2017)"),
        ("1917.2019.1080p.BluRay", "1917 (2019)"),
        ("Friends.1x05.HDTV", "Friends S01E05"),
        ("Oppenheimer (2023) 1080p WEB-DL", "Oppenheimer (2023)"),
        // Nombres que no son releases: casi intactos.
        ("Ubuntu 24.04 LTS Desktop amd64.iso", "Ubuntu 24.04 LTS Desktop amd64"),
        ("Next-Level HDR Performance | 8K Dolby Vision 60fps (4K/8K TV)",
         "Next-Level HDR Performance | 8K Dolby Vision 60fps (4K/8K TV)"),
        ("Holiday photos", "Holiday photos"),
    ]

    func testCleanTitles() {
        for (raw, expected) in cases {
            XCTAssertEqual(CleanTitle.make(raw), expected, raw)
        }
    }

    func testNeverEmpty() {
        for raw in [".mkv", "[TAG]", "1080p", "S01E01"] {
            XCTAssertFalse(CleanTitle.make(raw).trimmingCharacters(in: .whitespaces).isEmpty, raw)
        }
    }
}
