import SwiftUI

/// Colores de la marca, sacados del ícono.
enum Brand {
    static let mint = Color(red: 0.478, green: 0.922, blue: 0.635)      // #7AEBA2, cara de arriba
    static let green = Color(red: 0.165, green: 0.659, blue: 0.400)     // #2AA866, cara izquierda
    static let deep = Color(red: 0.106, green: 0.510, blue: 0.282)      // #1B8248, cara derecha
    static let soft = Color(red: 0.624, green: 0.851, blue: 0.706)      // #9FD9B4, textos suaves
    static let ink = Color(red: 0.020, green: 0.051, blue: 0.035)       // #050D09, fondo

    /// Fondo verde oscuro con un brillo al centro.
    static var background: some View {
        RadialGradient(colors: [Color(red: 0.05, green: 0.23, blue: 0.14),
                                Color(red: 0.03, green: 0.10, blue: 0.06), ink],
                       center: UnitPoint(x: 0.5, y: 0.4), startRadius: 0, endRadius: 520)
            .ignoresSafeArea()
    }
}

/// El cubo del ícono, dibujado (no imagen) para poder animar sus partes.
struct BrandCube: View {
    /// 0 = cubo escondido, 1 = cubo armado.
    var cube: CGFloat = 1
    /// Desplazamiento vertical de la flecha, en unidades del dibujo (160 = alto total). Negativo = más arriba.
    var arrowOffset: CGFloat = 0
    var arrowOpacity: Double = 1

    var body: some View {
        Canvas { ctx, size in
            let s = min(size.width, size.height) / 160
            func pt(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * s, y: y * s) }
            func poly(_ p: [(CGFloat, CGFloat)]) -> Path {
                var path = Path()
                path.addLines(p.map { pt($0.0, $0.1) })
                path.closeSubpath()
                return path
            }
            var c = ctx
            c.opacity = Double(cube)
            c.translateBy(x: 0, y: (1 - cube) * 30 * s)
            c.fill(poly([(80, 18), (138, 50), (80, 82), (22, 50)]), with: .color(Brand.mint))
            c.fill(poly([(22, 50), (80, 82), (80, 146), (22, 114)]), with: .color(Brand.green))
            c.fill(poly([(138, 50), (80, 82), (80, 146), (138, 114)]), with: .color(Brand.deep))

            var a = ctx
            a.opacity = arrowOpacity
            a.translateBy(x: 0, y: arrowOffset * s)
            a.fill(Path(CGRect(x: 74 * s, y: 60 * s, width: 12 * s, height: 28 * s)), with: .color(.white))
            a.fill(poly([(62, 86), (98, 86), (80, 108)]), with: .color(.white))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityLabel("T-Box")
    }
}

/// Firma "Creado por maniac75".
struct MadeBy: View {
    var body: some View {
        HStack(spacing: 4) {
            Text("Creado por").foregroundStyle(Brand.soft.opacity(0.8))
            Text(verbatim: "maniac75").fontWeight(.bold).foregroundStyle(Brand.mint)
        }
        .font(.footnote)
    }
}

/// Pantalla mientras carga la biblioteca por primera vez: el cubo respira y la flecha cae.
/// No agrega espera: desaparece apenas llegan los datos.
struct LibraryLoadingView: View {
    @State private var breathe = false
    @State private var spin = false
    @State private var step = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let messages = ["Conectando con TorBox…", "Cargando tu biblioteca…", "Casi listo…"]

    var body: some View {
        ZStack {
            Brand.background
            VStack(spacing: 28) {
                ZStack {
                    Circle()
                        .trim(from: 0, to: 0.25)
                        .stroke(Brand.mint, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                        .background(Circle().stroke(Brand.mint.opacity(0.12), lineWidth: 2.5))
                        .rotationEffect(.degrees(spin ? 360 : 0))
                        .frame(width: 140, height: 140)
                    TimelineView(.animation(paused: reduceMotion)) { tl in
                        let t = tl.date.timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 1.2) / 1.2
                        let a = reduceMotion ? (offset: CGFloat(0), opacity: 1.0) : arrowPhase(t)
                        BrandCube(cube: 1, arrowOffset: a.offset, arrowOpacity: a.opacity)
                    }
                    .frame(width: 90, height: 90)
                    .scaleEffect(breathe ? 1.04 : 1)
                    .offset(y: breathe ? -5 : 0)
                    .shadow(color: Brand.mint.opacity(breathe ? 0.6 : 0.25), radius: breathe ? 26 : 12)
                }
                VStack(spacing: 8) {
                    Text(verbatim: "T-Box").font(.title.bold())
                    Text(LocalizedStringKey(messages[step]))
                        .font(.subheadline)
                        .foregroundStyle(Brand.soft)
                        .id(step)
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                }
            }
            VStack {
                Spacer()
                MadeBy().padding(.bottom, 24)
            }
        }
        .foregroundStyle(.white)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(L("Cargando tu biblioteca…"))
        .task {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1).repeatForever(autoreverses: true)) { breathe = true }
            withAnimation(.linear(duration: 1.1).repeatForever(autoreverses: false)) { spin = true }
            while !Task.isCancelled, step < messages.count - 1 {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                withAnimation(.easeOut(duration: 0.3)) { step += 1 }
            }
        }
    }

    /// La flecha baja desde arriba, se queda un momento y se hunde en el cubo.
    private func arrowPhase(_ t: Double) -> (offset: CGFloat, opacity: Double) {
        switch t {
        case ..<0.3: return (CGFloat(-18 + 18 * t / 0.3), t / 0.3)
        case ..<0.75: return (0, 1)
        default:
            let k = (t - 0.75) / 0.25
            return (CGFloat(10 * k), 1 - k)
        }
    }
}
