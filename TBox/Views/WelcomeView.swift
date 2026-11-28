import SwiftUI

/// Bienvenida animada. Se muestra la primera vez y tras una actualización grande (cambia `WelcomeView.edition`).
struct WelcomeView: View {
    /// Subirlo hace que la bienvenida vuelva a aparecer una vez tras actualizar.
    static let edition = "0.5.0"

    /// true: quien ya vio una bienvenida anterior ve solo la tarjeta de novedades.
    var whatsNew = false
    let onDone: () -> Void

    @State private var step = 0
    @State private var showSafariHelp = false
    @Environment(\.openURL) private var openURL

    private static var appVersion: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? ""
    }

    private struct Card { let icon: String; let title: LocalizedStringKey; let body: LocalizedStringKey }
    private let cards: [Card] = [
        Card(icon: "arrow.down.to.line",
             title: "Descargas 10 veces más rápidas",
             body: "Baja tus archivos de TorBox al iPhone en varias partes a la vez. Sigue bajando aunque cierres la app."),
        Card(icon: "platter.filled.top.iphone",
             title: "Todo a la vista",
             body: "El avance, la velocidad y el tiempo restante en la Dynamic Island y en la pantalla de bloqueo."),
        Card(icon: "books.vertical",
             title: "Tu biblioteca, ordenada",
             body: "Torrents y descargas web juntos, con filtros, favoritos y selección múltiple."),
        Card(icon: "safari",
             title: "Directo desde Safari",
             body: "En los sitios compatibles aparece un botón para enviar el enlace a T-Box. Actívala en Ajustes › Apps › Safari › Extensiones.")
    ]

    var body: some View {
        ZStack {
            Brand.background
            MovingGrid()
            if whatsNew {
                whatsNewStep
            } else {
                switch step {
                case 0: SplashStep { advance() }
                case 1...cards.count: cardStep(cards[step - 1])
                default: endStep
                }
            }
        }
        .foregroundStyle(.white)
        .preferredColorScheme(.dark)
        .animation(.easeInOut(duration: 0.35), value: step)
    }

    private func advance() { step = min(step + 1, cards.count + 1) }

    private func cardStep(_ c: Card) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                BrandCube().frame(width: 34, height: 34)
                Spacer()
                Button("Saltar") { step = cards.count + 1 }
                    .foregroundStyle(Brand.soft)
                    .frame(minHeight: 44)
            }
            Spacer()
            VStack(alignment: .leading, spacing: 22) {
                Image(systemName: c.icon)
                    .font(.system(size: 42, weight: .medium))
                    .foregroundStyle(Brand.mint)
                    .frame(width: 96, height: 96)
                    .background(LinearGradient(colors: [Brand.deep, Color(red: 0.05, green: 0.23, blue: 0.14)],
                                               startPoint: .topLeading, endPoint: .bottomTrailing),
                                in: RoundedRectangle(cornerRadius: 28))
                    .overlay(RoundedRectangle(cornerRadius: 28).stroke(Brand.mint.opacity(0.35)))
                    .shadow(color: Brand.mint.opacity(0.25), radius: 20)
                Text(c.title).font(.system(size: 32, weight: .bold)).fixedSize(horizontal: false, vertical: true)
                Text(c.body).font(.title3).foregroundStyle(Brand.soft)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .id(step)
            .transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity),
                                    removal: .move(edge: .leading).combined(with: .opacity)))
            Spacer()
            HStack(spacing: 8) {
                ForEach(1...cards.count, id: \.self) { i in
                    Capsule().fill(i == step ? Brand.mint : Brand.mint.opacity(0.3))
                        .frame(width: i == step ? 24 : 8, height: 8)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 24)
            .accessibilityHidden(true)
            primaryButton("Siguiente") { advance() }
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private var endStep: some View {
        VStack(spacing: 18) {
            Spacer()
            BrandCube().frame(width: 96, height: 96)
                .shadow(color: Brand.mint.opacity(0.5), radius: 24)
            Text("Todo listo").font(.system(size: 30, weight: .bold))
            Text("App gratuita y de código abierto. No oficial: no está afiliada a TorBox.")
                .font(.body).foregroundStyle(Brand.soft).multilineTextAlignment(.center)
            VStack(spacing: 6) {
                Text("Creado por").font(.footnote).textCase(.uppercase).foregroundStyle(Brand.soft)
                Text(verbatim: "maniac75").font(.title2.bold())
                Button { openURL(AppConfig.repoURL) } label: {
                    Label { Text(verbatim: "github.com/maniac75/t-box-for-torbox") }
                        icon: { Image(systemName: "chevron.left.forwardslash.chevron.right") }
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(Brand.mint)
                .frame(minHeight: 44)
            }
            .frame(maxWidth: .infinity)
            .padding(16)
            .background(Brand.mint.opacity(0.07), in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).stroke(Brand.mint.opacity(0.25)))
            Spacer()
            primaryButton("Empezar") { onDone() }
            versionFooter.padding(.top, 14)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
        .transition(.opacity)
    }

    private var whatsNewStep: some View {
        VStack(alignment: .leading, spacing: 0) {
            BrandCube().frame(width: 34, height: 34).frame(minHeight: 44)
            Spacer()
            VStack(alignment: .leading, spacing: 22) {
                Text("Nuevo en \(Self.appVersion)").font(.footnote.weight(.semibold)).textCase(.uppercase)
                    .foregroundStyle(Brand.mint)
                Text("Directo desde Safari").font(.system(size: 32, weight: .bold))
                newRow(icon: "safari",
                       text: "En los sitios compatibles aparece un botón para enviar el enlace a T-Box, sin copiar ni pegar.")
                newRow(icon: "doc.badge.arrow.up",
                       text: "Ahora también puedes agregar enlaces directos a archivos .torrent.")
                Button { withAnimation { showSafariHelp.toggle() } } label: {
                    Label("Cómo activarla", systemImage: showSafariHelp ? "chevron.up" : "questionmark.circle")
                        .font(.subheadline.weight(.medium))
                }
                .foregroundStyle(Brand.mint)
                .frame(minHeight: 44)
                if showSafariHelp { safariHelp.transition(.opacity.combined(with: .move(edge: .top))) }
            }
            Spacer()
            primaryButton("Entendido") { onDone() }
            versionFooter.padding(.top, 14)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 20)
    }

    private func newRow(icon: String, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(Brand.mint).frame(width: 32)
            Text(text).font(.body).foregroundStyle(Brand.soft).fixedSize(horizontal: false, vertical: true)
        }
    }

    private var safariHelp: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("1. Abre Ajustes › Apps › Safari › Extensiones (en iOS 17: Ajustes › Safari › Extensiones).")
            Text("2. Toca T-Box y actívala.")
            Text("3. En «Todos los sitios web», elige «Permitir».")
        }
        .font(.subheadline)
        .foregroundStyle(Brand.soft)
        .fixedSize(horizontal: false, vertical: true)
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Brand.mint.opacity(0.07), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(Brand.mint.opacity(0.25)))
    }

    private var versionFooter: some View {
        Text(verbatim: "v\(Self.appVersion)")
            .font(.caption2.monospacedDigit())
            .foregroundStyle(Brand.soft.opacity(0.6))
            .frame(maxWidth: .infinity)
    }

    private func primaryButton(_ title: LocalizedStringKey, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title).font(.headline).frame(maxWidth: .infinity, minHeight: 54)
        }
        .foregroundStyle(Color(red: 0.02, green: 0.13, blue: 0.08))
        .background(Brand.mint, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: Brand.mint.opacity(0.35), radius: 14)
    }
}

/// Primera pantalla: el cubo se arma, cae la flecha, pulso de luz, línea de escaneo y barra de carga.
private struct SplashStep: View {
    let onContinue: () -> Void
    @State private var cube: CGFloat = 0
    @State private var arrowOffset: CGFloat = -60
    @State private var arrowOpacity = 0.0
    @State private var showText = false
    @State private var bar: CGFloat = 0
    @State private var pulse = false
    @State private var scan: CGFloat = -0.1
    @State private var showButton = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Rectangle()
                    .fill(LinearGradient(colors: [.clear, Brand.mint, .clear], startPoint: .leading, endPoint: .trailing))
                    .frame(height: 2)
                    .shadow(color: Brand.mint, radius: 8)
                    .position(x: geo.size.width / 2, y: geo.size.height * scan)
                    .opacity(scan > 0 && scan < 1.05 ? 1 : 0)
                    .accessibilityHidden(true)

                VStack(spacing: 28) {
                    ZStack {
                        Circle().stroke(Brand.mint, lineWidth: 2)
                            .frame(width: 150, height: 150)
                            .scaleEffect(pulse ? 1.9 : 0.6)
                            .opacity(pulse ? 0 : (cube > 0.9 ? 0.7 : 0))
                            .accessibilityHidden(true)
                        BrandCube(cube: cube, arrowOffset: arrowOffset, arrowOpacity: arrowOpacity)
                            .frame(width: 160, height: 160)
                            .shadow(color: Brand.mint.opacity(0.45), radius: 24)
                    }
                    VStack(spacing: 10) {
                        Text(verbatim: "T-Box").font(.system(size: 46, weight: .bold))
                        Text("TorBox, directo en tu iPhone").font(.subheadline).foregroundStyle(Brand.soft)
                    }
                    .opacity(showText ? 1 : 0)
                    .offset(y: showText ? 0 : 14)
                    Capsule().fill(Brand.mint.opacity(0.18))
                        .frame(width: 160, height: 4)
                        .overlay(alignment: .leading) {
                            Capsule().fill(Brand.mint).frame(width: 160 * bar, height: 4)
                                .shadow(color: Brand.mint, radius: 6)
                        }
                        .opacity(showText ? 1 : 0)
                        .accessibilityHidden(true)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                VStack {
                    Spacer()
                    Button("Toca para continuar", action: onContinue)
                        .font(.subheadline.weight(.medium))
                        .padding(.horizontal, 22)
                        .frame(minHeight: 44)
                        .background(Brand.mint.opacity(0.08), in: Capsule())
                        .overlay(Capsule().stroke(Brand.mint.opacity(0.4)))
                        .foregroundStyle(Color(red: 0.84, green: 0.97, blue: 0.88))
                        .opacity(showButton ? 1 : 0)
                        .padding(.bottom, 40)
                }
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { if showButton { onContinue() } }
        .task { await play() }
    }

    private func play() async {
        if reduceMotion {
            cube = 1; arrowOffset = 0; arrowOpacity = 1; showText = true; bar = 1; showButton = true
            return
        }
        withAnimation(.linear(duration: 2.2)) { scan = 1.1 }
        try? await Task.sleep(nanoseconds: 200_000_000)
        withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) { cube = 1 }
        try? await Task.sleep(nanoseconds: 700_000_000)
        withAnimation(.spring(response: 0.5, dampingFraction: 0.55)) { arrowOffset = 0; arrowOpacity = 1 }
        try? await Task.sleep(nanoseconds: 400_000_000)
        withAnimation(.easeOut(duration: 1.8).repeatForever(autoreverses: false)) { pulse = true }
        withAnimation(.easeOut(duration: 0.6)) { showText = true }
        withAnimation(.easeInOut(duration: 1.4).delay(0.3)) { bar = 1 }
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        withAnimation(.easeOut(duration: 0.5)) { showButton = true }
    }
}

/// Grilla en perspectiva que avanza, abajo de la pantalla.
private struct MovingGrid: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            TimelineView(.animation(paused: reduceMotion)) { tl in
                let shift = CGFloat(tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.6) / 1.6) * 40
                Canvas { ctx, size in
                    var path = Path()
                    var y = shift
                    while y < size.height { path.move(to: CGPoint(x: 0, y: y)); path.addLine(to: CGPoint(x: size.width, y: y)); y += 40 }
                    var x: CGFloat = 0
                    while x < size.width { path.move(to: CGPoint(x: x, y: 0)); path.addLine(to: CGPoint(x: x, y: size.height)); x += 40 }
                    ctx.stroke(path, with: .color(Brand.mint.opacity(0.16)), lineWidth: 1)
                }
                .frame(width: geo.size.width * 1.8, height: geo.size.height * 0.46)
                .rotation3DEffect(.degrees(62), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.8)
                .mask(LinearGradient(colors: [.clear, .black], startPoint: .top, endPoint: .center))
                .position(x: geo.size.width / 2, y: geo.size.height * 0.80)
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
