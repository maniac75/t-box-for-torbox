import Foundation
import UIKit

/// Todo lo que alguien que compile su propia versión querría cambiar está aquí.
enum AppConfig {
    static let displayName = "T-Box"

    /// Código de referido de TorBox del autor de la app.
    /// Quien lo usa y quien lo comparte reciben días extra al comprar un plan pagado.
    static let referralCode = "7b4a584a-00a5-430e-aa31-809aa4934cb0"
    static var referralURL: URL {
        URL(string: "https://torbox.app/subscription?referral=\(referralCode)")!
    }

    static let koFiURL = URL(string: "https://ko-fi.com/supermaniac")!
    static let sponsorsURL = URL(string: "https://github.com/sponsors/maniac75")!
    static var bugReportURL: URL {
        let app = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "?"
        var c = URLComponents(string: "https://github.com/maniac75/t-box-for-torbox/issues/new")!
        c.queryItems = [
            URLQueryItem(name: "template", value: "bug_report.yml"),
            URLQueryItem(name: "version", value: "\(app) (\(build))"),
            URLQueryItem(name: "ios", value: "iOS \(UIDevice.current.systemVersion), \(Diagnostics.deviceModel)")
        ]
        return c.url!
    }
    static let featureRequestURL = URL(string: "https://github.com/maniac75/t-box-for-torbox/issues/new?template=feature_request.yml")!
    static let discussionsURL = URL(string: "https://github.com/maniac75/t-box-for-torbox/discussions")!
    static let repoURL = URL(string: "https://github.com/maniac75/t-box-for-torbox")!
    /// Texto que acompaña al enlace al compartir T-Box.
    static var shareMessage: String { L("T-Box: una app gratis y de código abierto para usar TorBox en el iPhone.") }
    static var privacyURL: URL {
        let es = Locale.current.language.languageCode?.identifier == "es"
        return URL(string: "https://github.com/maniac75/t-box-for-torbox/blob/main/\(es ? "PRIVACY.es.md" : "PRIVACY.md")")!
    }
}

/// Texto traducible (español base, inglés en Localizable.xcstrings).
func L(_ key: String) -> String {
    NSLocalizedString(key, comment: "")
}
