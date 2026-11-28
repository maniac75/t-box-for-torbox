import SwiftUI

/// Tarjeta que pide ayuda para difundir T-Box. Aparece una sola vez, tras la tercera descarga completada.
struct ShareCard: View {
    let onClose: () -> Void
    @Environment(\.openURL) private var openURL

    var body: some View {
        VStack(spacing: 14) {
            BrandCube().frame(width: 44, height: 44)
            Text("¿Te sirve T-Box?").font(.title3.bold())
            Text("Ayúdanos a que más gente la conozca. Toma un segundo y hace una gran diferencia.")
                .font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
            VStack(spacing: 8) {
                ShareLink(item: AppConfig.repoURL, message: Text(AppConfig.shareMessage)) {
                    Label("Compartir T-Box", systemImage: "square.and.arrow.up").frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                Button {
                    onClose()
                    openURL(AppConfig.repoURL)
                } label: {
                    Label("Dar una estrella en GitHub", systemImage: "star").frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            Button("Ahora no") { onClose() }
                .font(.subheadline)
        }
        .padding(24)
        .tint(.green)
    }
}

/// Acerca de T-Box: logo, versión, autor y formas de apoyar.
struct AboutView: View {
    @State private var breathe = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var version: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(v) (\(b))"
    }

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    BrandCube()
                        .frame(width: 96, height: 96)
                        .scaleEffect(breathe ? 1.04 : 1)
                        .shadow(color: Brand.mint.opacity(breathe ? 0.55 : 0.2), radius: breathe ? 22 : 10)
                    Text(verbatim: "T-Box").font(.title.bold())
                    Text(String(format: L("Versión %@"), version)).font(.subheadline).foregroundStyle(.secondary)
                    HStack(spacing: 4) {
                        Text("Creado por").foregroundStyle(.secondary)
                        Text(verbatim: "maniac75").fontWeight(.semibold)
                    }
                    .font(.subheadline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .listRowBackground(Color.clear)
            }

            Section {
                ShareLink(item: AppConfig.repoURL, message: Text(AppConfig.shareMessage)) {
                    Label("Compartir T-Box", systemImage: "square.and.arrow.up")
                }
                Link(destination: AppConfig.repoURL) {
                    Label("Dar una estrella en GitHub", systemImage: "star")
                }
            } header: {
                Text("Ayuda a difundirla")
            } footer: {
                Text("Las estrellas ayudan a que más gente encuentre T-Box en GitHub.")
            }

            Section("Apoyar T-Box") {
                Link(destination: AppConfig.koFiURL) {
                    Label("Invítame un café", systemImage: "cup.and.saucer")
                }
                Link(destination: AppConfig.sponsorsURL) {
                    Label("Patrocinar en GitHub", systemImage: "heart")
                }
            }

            Section {
                Link(destination: AppConfig.repoURL) {
                    Label("Código fuente en GitHub", systemImage: "chevron.left.forwardslash.chevron.right")
                }
                Link(destination: AppConfig.privacyURL) {
                    Label("Política de privacidad", systemImage: "hand.raised")
                }
            } footer: {
                Text("App gratuita y de código abierto. No oficial: no está afiliada a TorBox.")
            }
        }
        .navigationTitle("Acerca de")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true)) { breathe = true }
        }
    }
}
