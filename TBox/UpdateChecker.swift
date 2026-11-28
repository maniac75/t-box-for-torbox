import Foundation
import UIKit

/// Revisa en GitHub si hay una versión más nueva de T-Box.
/// Una consulta pública a api.github.com, sin cuenta ni datos personales; como máximo una vez por hora (cada 5 minutos al entrar a Cuenta).
final class UpdateChecker: ObservableObject {
    static let shared = UpdateChecker()

    @Published private(set) var latestVersion: String?
    /// Enlace que abre Feather y le pasa la ipa de la versión nueva (queda en "Imported", lista para firmar).
    /// Nil si no hay versión nueva o Feather no está instalado.
    var featherInstallURL: URL? {
        guard updateAvailable, let v = latestVersion,
              let feather = URL(string: "feather://"), UIApplication.shared.canOpenURL(feather) else { return nil }
        return URL(string: "feather://install/https://github.com/maniac75/t-box-for-torbox/releases/download/v\(v)/T-Box-\(v).ipa")
    }

    @Published private(set) var releaseURL = URL(string: "https://github.com/maniac75/t-box-for-torbox/releases/latest")!

    var current: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    }

    /// Hay versión nueva si la última publicada es mayor que la instalada.
    var updateAvailable: Bool {
        guard let latestVersion else { return false }
        return Self.isNewer(latestVersion, than: current)
    }

    private init() {
        latestVersion = UserDefaults.standard.string(forKey: "update.latest")
    }

    /// `minInterval`: segundos mínimos desde la última consulta.
    func check(minInterval: TimeInterval = 3600) async {
        let last = UserDefaults.standard.double(forKey: "update.checkedAt")
        if Date().timeIntervalSince1970 - last < minInterval { return }
        var req = URLRequest(url: URL(string: "https://api.github.com/repos/maniac75/t-box-for-torbox/releases/latest")!)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        req.timeoutInterval = 15
        guard let (data, resp) = try? await URLSession.shared.data(for: req),
              (resp as? HTTPURLResponse)?.statusCode == 200,
              let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = obj["tag_name"] as? String else { return }
        let version = tag.hasPrefix("v") ? String(tag.dropFirst()) : tag
        let page = (obj["html_url"] as? String).flatMap(URL.init(string:))
        await MainActor.run {
            self.latestVersion = version
            if let page { self.releaseURL = page }
        }
        UserDefaults.standard.set(version, forKey: "update.latest")
        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: "update.checkedAt")
    }

    /// Compara versiones numéricas ("0.3.10" > "0.3.9").
    static func isNewer(_ a: String, than b: String) -> Bool {
        let pa = a.split(separator: ".").map { Int($0) ?? 0 }
        let pb = b.split(separator: ".").map { Int($0) ?? 0 }
        for i in 0..<max(pa.count, pb.count) {
            let x = i < pa.count ? pa[i] : 0, y = i < pb.count ? pb[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
