import SwiftUI
import AVFoundation
import UserNotifications

final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    func application(_ application: UIApplication,
                     didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
        _ = DownloadManager.shared
        UNUserNotificationCenter.current().delegate = self
        BackgroundCheck.register()
        Task { @MainActor in LiveDownloads.shared.start() }
        return true
    }

    func application(_ application: UIApplication, handleEventsForBackgroundURLSession identifier: String,
                     completionHandler: @escaping () -> Void) {
        DownloadManager.shared.backgroundCompletion = completionHandler
    }

    // Con la app abierta se usa el aviso interno; esto cubre notificaciones que llegan justo al volver.
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound])
    }
}

@main
struct TBoxApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state = AppState()
    @StateObject private var downloads = DownloadManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(state)
                .environmentObject(downloads)
                .onOpenURL { url in state.handle(url: url) }
        }
    }
}

struct RootView: View {
    @EnvironmentObject private var state: AppState
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("support.completed") private var completedDownloads = 0
    @AppStorage("support.asked") private var supportAsked = false
    @AppStorage("share.asked") private var shareAsked = false
    @AppStorage("welcome.seen") private var welcomeSeen = ""
    /// Descargas completadas al abrir la app: las tarjetas solo aparecen después de terminar una descarga
    /// en esta sesión, nunca al abrir (ni encima de la bienvenida).
    @State private var completedAtLaunch = UserDefaults.standard.integer(forKey: "support.completed")
    private var cardsAllowed: Bool {
        welcomeSeen == WelcomeView.edition && !state.showAdd && completedDownloads > completedAtLaunch
    }
    @ObservedObject private var updates = UpdateChecker.shared

    var body: some View {
        Group {
            if state.isLoggedIn {
                TabView {
                    LibraryView()
                        .tabItem { Label("Biblioteca", systemImage: "books.vertical") }
                    DownloadsView()
                        .withActivityBar()
                        .tabItem { Label("En el iPhone", systemImage: "arrow.down.circle") }
                    SettingsView()
                        .tabItem { Label("Cuenta", systemImage: "person.crop.circle") }
                        .badge(updates.updateAvailable ? 1 : 0)
                }
                .task { await updates.check() }
                .sheet(isPresented: $state.showAdd) {
                    AddView(initialText: state.incomingText, initialFile: state.incomingTorrentFile)
                }
                // Una tarjeta a la vez: compartir tras la 3.ª descarga, apoyar tras la 10.ª.
                .sheet(isPresented: Binding(get: { cardsAllowed && completedDownloads >= 3 && !shareAsked },
                                            set: { if !$0 { shareAsked = true } })) {
                    ShareCard { shareAsked = true }
                        .presentationDetents([.height(380)])
                }
                .sheet(isPresented: Binding(get: { cardsAllowed && completedDownloads >= 10 && shareAsked && !supportAsked },
                                            set: { if !$0 { supportAsked = true } })) {
                    SupportCard { supportAsked = true }
                        .presentationDetents([.height(330)])
                }
                .onAppear { AppSettings.setDestination(nil) }
            } else {
                LoginView()
            }
        }
        .overlay(alignment: .top) { ToastView().animation(.spring, value: Toaster.shared.current) }
        .fullScreenCover(isPresented: Binding(get: { welcomeSeen != WelcomeView.edition },
                                              set: { if !$0 { welcomeSeen = WelcomeView.edition } })) {
            WelcomeView { welcomeSeen = WelcomeView.edition }
        }
        .tint(.green)
        .onChange(of: scenePhase) { _, phase in
            if phase == .active, state.isLoggedIn {
                Task { await state.refresh() }
                state.startPolling()
            } else if phase == .background {
                state.stopPolling()
                if state.isLoggedIn { BackgroundCheck.schedule() }
            }
        }
    }
}
