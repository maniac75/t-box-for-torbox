import SwiftUI
import UniformTypeIdentifiers
import UIKit

struct SettingsView: View {
    @ObservedObject private var updates = UpdateChecker.shared
    @EnvironmentObject private var state: AppState
    @Environment(\.openURL) private var openURL
    @State private var confirmLogout = false
    @State private var confirmCopyKey = false
    @State private var confirmReferral = false
    @State private var notice: String?
    @State private var shareURL: URL?
    @State private var busy = false
    @State private var unzip = AppSettings.unzipAfterDownload
    @State private var multipart = AppSettings.multipartDownloads
    @State private var notificationsOn = Notifier.enabled
    @State private var ntfyTopic = AppSettings.ntfyTopic
    @State private var confirmNtfy = false

    var body: some View {
        NavigationStack {
            Form {
                if updates.updateAvailable, let v = updates.latestVersion {
                    Section {
                        Link(destination: updates.releaseURL) {
                            Label(String(format: L("T-Box %@ disponible"), v), systemImage: "arrow.down.app.fill")
                                .font(.headline)
                        }
                    } footer: {
                        Text(String(format: L("Tienes la %@. Descarga la nueva y fírmala como siempre, o actualízala desde la fuente de T-Box en Feather."), updates.current))
                    }
                }

                Section("Cuenta TorBox") {
                    LabeledContent("Correo", value: state.user?.email ?? "—")
                    LabeledContent("Plan", value: state.user?.planName ?? "—")
                    if let exp = state.user?.premiumExpiresAt {
                        LabeledContent("Vence", value: formatted(exp))
                    }
                    Button("Abrir torbox.app") {
                        if let url = URL(string: "https://torbox.app/dashboard") { openURL(url) }
                    }
                    Button("Copiar API key") { confirmCopyKey = true }
                }

                if let code = state.referral?.code, let link = state.referral?.shareURL {
                    Section {
                        LabeledContent("Tu código", value: code)
                        if let n = state.referral?.count {
                            LabeledContent("Cuentas referidas", value: "\(n)")
                        }
                        ShareLink(item: link) { Label("Compartir tu enlace de referido", systemImage: "square.and.arrow.up") }
                        Button("Copiar código") { UIPasteboard.general.string = code; notice = L("Código copiado") }
                    } header: {
                        Text("Invita a tus amigos")
                    } footer: {
                        Text("Si alguien compra un plan con tu enlace, TorBox les da días extra a ambos.")
                    }
                }

                if state.user?.isFree == true {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Pasa a un plan pagado").font(.headline)
                            Text("Con un plan pagado tienes descargas web (YouTube, Instagram, Mega…) y más descargas simultáneas. Usando el código de referido de T-Box recibes días extra al comprar.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                        Link(destination: AppConfig.referralURL) {
                            Label("Ver planes con código de referido", systemImage: "gift")
                        }
                    }
                }

                Section {
                    LabeledContent("Torrents", value: "\(state.torrents.count)")
                    LabeledContent("Descargas web", value: "\(state.webDownloads.count)")
                } footer: {
                    Text("Para mandar enlaces desde Instagram, YouTube, Safari u otra app, usa Compartir › T-Box. Tocar un magnet en Safari también abre la app.")
                }

                Section {
                    LabeledContent("Carpeta", value: L("Archivos › En mi iPhone › T-Box"))
                    Toggle("Descomprimir .zip al terminar", isOn: $unzip)
                        .onChange(of: unzip) { _, v in AppSettings.unzipAfterDownload = v }
                    Toggle("Descarga rápida en varias partes", isOn: $multipart)
                        .onChange(of: multipart) { _, v in AppSettings.multipartDownloads = v }
                } header: {
                    Text("Descargas")
                } footer: {
                    Text("Lo que bajes queda en la carpeta T-Box de la app Archivos, aunque la app esté cerrada. Para llevar un archivo a iCloud u otra carpeta: En el iPhone › desliza › Compartir › Guardar en Archivos.\n\nLa descarga rápida pide los archivos de más de 32 MB en 4 a 6 partes a la vez y las une al final. Si algo falla, desactívala.")
                }

                Section {
                    Toggle("Notificaciones", isOn: $notificationsOn)
                        .onChange(of: notificationsOn) { _, v in
                            Notifier.enabled = v
                            if v { Task { await Notifier.requestPermission() } }
                        }
                    Button("Probar notificación") {
                        Task {
                            if await Notifier.requestPermission() {
                                Notifier.post(L("T-Box"), detail: L("Las notificaciones funcionan."), id: "test-\(Date().timeIntervalSince1970)")
                            } else {
                                notice = L("iOS tiene bloqueadas las notificaciones de T-Box. Actívalas en Ajustes › Apps › T-Box › Notificaciones.")
                            }
                        }
                    }
                    .disabled(!notificationsOn)
                } header: {
                    Text("Avisos")
                } footer: {
                    Text("Avisa cuando termina una descarga al iPhone y cuando algo queda listo en TorBox. Con la app cerrada, iOS decide cada cuánto revisar TorBox (de minutos a horas).")
                }

                Section {
                    if let topic = ntfyTopic {
                        LabeledContent("Tema", value: topic)
                        Button("Copiar tema") {
                            UIPasteboard.general.string = topic
                            notice = L("Tema copiado")
                        }
                        Link("Abrir en ntfy.sh", destination: URL(string: "https://ntfy.sh/\(topic)")!)
                        Button("Enviar aviso de prueba") { Task { await ntfyTest() } }.disabled(busy)
                        Button("Desactivar", role: .destructive) { Task { await ntfyDisable() } }.disabled(busy)
                    } else {
                        Button("Activar avisos instantáneos con ntfy") { confirmNtfy = true }.disabled(busy)
                    }
                } header: {
                    Text("Avisos instantáneos (experimental)")
                } footer: {
                    Text("TorBox envía un aviso a ntfy apenas termina algo, aunque T-Box esté cerrada. Instala la app gratuita ntfy y suscríbete al tema que aparece aquí. El tema es aleatorio: quien no lo conozca no ve tus avisos.")
                }

                Section {
                    Link(destination: AppConfig.bugReportURL) {
                        Label("Reportar un error", systemImage: "ladybug")
                    }
                    Link(destination: AppConfig.featureRequestURL) {
                        Label("Sugerir una mejora", systemImage: "lightbulb")
                    }
                    Link(destination: AppConfig.discussionsURL) {
                        Label("Preguntas y comunidad", systemImage: "bubble.left.and.bubble.right")
                    }
                } header: {
                    Text("Opina")
                } footer: {
                    Text("Se abre GitHub (necesitas una cuenta gratuita). Al reportar un error, la versión de la app y de iOS ya van completadas. Ayuda mucho adjuntar el diagnóstico de más abajo: la API key va censurada.")
                }

                Section {
                    Link(destination: AppConfig.koFiURL) {
                        Label("Invítame un café", systemImage: "cup.and.saucer")
                    }
                    Link(destination: AppConfig.sponsorsURL) {
                        Label("Patrocinar en GitHub", systemImage: "heart")
                    }
                    Button { confirmReferral = true } label: {
                        Label("Agregar código de referido de T-Box", systemImage: "gift")
                    }
                    .disabled(busy)
                } header: {
                    Text("Apoyar T-Box")
                } footer: {
                    Text("T-Box es gratis y siempre lo será. Estas opciones son voluntarias. El código de referido no te cuesta nada: ambos reciben días extra en tus próximas compras, y solo se envía si lo confirmas.")
                }

                Section("Diagnóstico") {
                    Button {
                        shareURL = Diagnostics.shared.exportFile(plan: state.user?.planName)
                    } label: {
                        Label("Exportar diagnóstico", systemImage: "doc.text.magnifyingglass")
                    }
                    Button("Borrar registro", role: .destructive) {
                        Diagnostics.shared.clear()
                        notice = L("Registro borrado")
                    }
                }

                Section {
                    Link(destination: AppConfig.repoURL) {
                        Label("Código fuente en GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                    }
                    Link(destination: AppConfig.privacyURL) {
                        Label("Política de privacidad", systemImage: "hand.raised")
                    }
                    Button("Cerrar sesión", role: .destructive) { confirmLogout = true }
                } footer: {
                    Text("\(AppConfig.displayName) \(appVersion) · " + L("Cliente no oficial para TorBox, sin relación con TorBox. Si vuelves a firmar la app con otro certificado, puede que tengas que iniciar sesión de nuevo."))
                }
            }
            .navigationTitle("Cuenta")
            .task {
                if state.user == nil { await state.refresh() }
                if state.referral == nil { await state.loadReferral() }
            }
            .confirmationDialog("¿Copiar tu API key?", isPresented: $confirmCopyKey, titleVisibility: .visible) {
                Button("Copiar") {
                    UIPasteboard.general.setItems([[UTType.plainText.identifier: state.currentAPIKey ?? ""]],
                                                  options: [.expirationDate: Date().addingTimeInterval(120)])
                    notice = L("API key copiada. Se borra del portapapeles en 2 minutos.")
                }
            } message: {
                Text("Quien tenga tu API key puede usar tu cuenta de TorBox. Pégala solo en apps de confianza.")
            }
            .confirmationDialog("¿Cerrar sesión? Se borra la API key del iPhone.",
                                isPresented: $confirmLogout, titleVisibility: .visible) {
                Button("Cerrar sesión", role: .destructive) { state.logout() }
            }
            .confirmationDialog("¿Asociar tu cuenta al código de referido de T-Box?",
                                isPresented: $confirmReferral, titleVisibility: .visible) {
                Button("Agregar código") { Task { await addReferral() } }
            } message: {
                Text("TorBox decidirá si se puede aplicar a tu cuenta.")
            }
            .confirmationDialog("¿Activar avisos instantáneos?", isPresented: $confirmNtfy, titleVisibility: .visible) {
                Button("Activar") { Task { await ntfyEnable() } }
            } message: {
                Text("T-Box configurará en tu cuenta de TorBox un webhook hacia ntfy.sh. Puedes desactivarlo cuando quieras.")
            }
            .alert(notice ?? "", isPresented: Binding(get: { notice != nil }, set: { if !$0 { notice = nil } })) {
                Button("OK", role: .cancel) {}
            }
            .sheet(item: Binding(get: { shareURL.map(IdentifiedURL.init) },
                                 set: { shareURL = $0?.url })) { item in
                ShareSheet(items: [item.url])
            }
        }
    }

    private var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "?"
    }

    private func ntfyEnable() async {
        busy = true
        defer { busy = false }
        let alphabet = Array("abcdefghijkmnopqrstuvwxyz23456789")
        let topic = "tbox-" + String((0..<18).map { _ in alphabet.randomElement()! })
        do {
            try await state.api.editSettings(["webhook_notifications": true,
                                              "webhook_url": "https://ntfy.sh/\(topic)"])
            AppSettings.ntfyTopic = topic
            ntfyTopic = topic
            notice = L("Listo. Suscríbete a este tema en la app ntfy y envía un aviso de prueba.")
        } catch {
            notice = error.localizedDescription
        }
    }

    private func ntfyTest() async {
        busy = true
        defer { busy = false }
        do { notice = try await state.api.sendTestNotification() ?? L("Aviso de prueba enviado") }
        catch { notice = error.localizedDescription }
    }

    private func ntfyDisable() async {
        busy = true
        defer { busy = false }
        do {
            try await state.api.editSettings(["webhook_notifications": false, "webhook_url": ""])
            AppSettings.ntfyTopic = nil
            ntfyTopic = nil
        } catch {
            notice = error.localizedDescription
        }
    }

    private func addReferral() async {
        busy = true
        defer { busy = false }
        do {
            let msg = try await state.api.addReferral(AppConfig.referralCode)
            notice = msg ?? L("Código agregado")
        } catch {
            notice = error.localizedDescription
        }
    }

    private func formatted(_ iso: String) -> String {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let d = f.date(from: iso) ?? {
            f.formatOptions = [.withInternetDateTime]
            return f.date(from: iso)
        }()
        guard let d else { return iso }
        return d.formatted(date: .abbreviated, time: .omitted)
    }
}

