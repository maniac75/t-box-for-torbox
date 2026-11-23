import Foundation
import SwiftUI
import UIKit
import UserNotifications

/// Avisos: dentro de la app un mensaje breve arriba; con la app en segundo plano, una notificación del sistema.
@MainActor
final class Toaster: ObservableObject {
    static let shared = Toaster()

    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let title: String
        let detail: String?
    }

    @Published var current: Toast?
    private var hideTask: Task<Void, Never>?

    func show(_ title: String, detail: String? = nil) {
        current = Toast(title: title, detail: detail)
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(nanoseconds: 3_500_000_000)
            if !Task.isCancelled { withAnimation { self.current = nil } }
        }
    }
}

enum Notifier {
    private static let enabledKey = "notifications.enabled"

    /// Preferencia del usuario (por defecto activadas; iOS igual pide permiso la primera vez).
    static var enabled: Bool {
        get { UserDefaults.standard.object(forKey: enabledKey) as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: enabledKey) }
    }

    @discardableResult
    static func requestPermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral: return true
        case .denied: return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    /// Aviso único: dentro de la app si está activa, notificación del sistema si no.
    static func announce(_ title: String, detail: String?, id: String = UUID().uuidString) {
        Task { @MainActor in
            if UIApplication.shared.applicationState == .active {
                Toaster.shared.show(title, detail: detail)
            } else {
                post(title, detail: detail, id: id)
            }
        }
    }

    static func post(_ title: String, detail: String?, id: String) {
        guard enabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        if let detail { content.body = detail }
        content.sound = .default
        let request = UNNotificationRequest(identifier: id, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

/// Ajustes locales de la app.
enum AppSettings {
    private static let d = UserDefaults.standard

    /// Bajar archivos grandes en varias partes a la vez (activado por omisión).
    static var multipartDownloads: Bool {
        get { d.object(forKey: "downloads.multipart") as? Bool ?? true }
        set { d.set(newValue, forKey: "downloads.multipart") }
    }

    static var unzipAfterDownload: Bool {
        get { d.bool(forKey: "downloads.unzip") }
        set { d.set(newValue, forKey: "downloads.unzip") }
    }

    /// Marcador de la carpeta elegida por el usuario (Archivos, iCloud Drive, USB…).
    static var destinationBookmark: Data? {
        get { d.data(forKey: "downloads.destination") }
        set { d.set(newValue, forKey: "downloads.destination") }
    }

    static var destinationName: String? {
        get { d.string(forKey: "downloads.destinationName") }
        set { d.set(newValue, forKey: "downloads.destinationName") }
    }

    static var ntfyTopic: String? {
        get { d.string(forKey: "ntfy.topic") }
        set { d.set(newValue, forKey: "ntfy.topic") }
    }

    static func resolveDestination() -> URL? {
        guard let data = destinationBookmark else { return nil }
        var stale = false
        guard let url = try? URL(resolvingBookmarkData: data, options: [], relativeTo: nil, bookmarkDataIsStale: &stale) else {
            return nil
        }
        if stale, url.startAccessingSecurityScopedResource() {
            destinationBookmark = try? url.bookmarkData()
            url.stopAccessingSecurityScopedResource()
        }
        return url
    }

    @discardableResult
    static func setDestination(_ url: URL?) -> Bool {
        guard let url else {
            destinationBookmark = nil
            destinationName = nil
            return true
        }
        let scoped = url.startAccessingSecurityScopedResource()
        defer { if scoped { url.stopAccessingSecurityScopedResource() } }
        do {
            destinationBookmark = try url.bookmarkData(options: [], includingResourceValuesForKeys: nil, relativeTo: nil)
            destinationName = url.lastPathComponent
            return true
        } catch {
            Diagnostics.log("FOLDER bookmark failed: \(error.localizedDescription)")
            return false
        }
    }
}
