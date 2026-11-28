import UIKit
import SwiftUI
import UniformTypeIdentifiers

/// Extensión de Compartir: aparece como "T-Box" en el menú Compartir de cualquier app.
/// Si puede leer la API key del llavero compartido, envía los enlaces a TorBox ahí mismo.
/// Si no, abre T-Box con los enlaces ya pegados.
final class ShareViewController: UIViewController {
    private let model = ShareModel()

    override func viewDidLoad() {
        super.viewDidLoad()
        model.close = { [weak self] in self?.extensionContext?.completeRequest(returningItems: nil) }
        model.openApp = { [weak self] url in self?.openInContainingApp(url) ?? false }
        let host = UIHostingController(rootView: ShareView(model: model))
        addChild(host)
        host.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(host.view)
        NSLayoutConstraint.activate([
            host.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            host.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            host.view.topAnchor.constraint(equalTo: view.topAnchor),
            host.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
        host.didMove(toParent: self)
        Task { await model.load(from: extensionContext?.inputItems as? [NSExtensionItem] ?? []) }
    }

    /// Las extensiones no pueden abrir URLs directamente; se busca la aplicación en la cadena
    /// de respondedores y se llama a open(_:options:completionHandler:) por el runtime de Objective-C.
    private func openInContainingApp(_ url: URL) -> Bool {
        let selector = NSSelectorFromString("openURL:options:completionHandler:")
        var responder: UIResponder? = self
        while let r = responder {
            if r.isKind(of: NSClassFromString("UIApplication") ?? UIResponder.self), r.responds(to: selector),
               let imp = r.method(for: selector) {
                typealias OpenFn = @convention(c) (AnyObject, Selector, NSURL, NSDictionary, (@convention(block) (Bool) -> Void)?) -> Void
                let fn = unsafeBitCast(imp, to: OpenFn.self)
                fn(r, selector, url as NSURL, NSDictionary(), nil)
                return true
            }
            responder = r.next
        }
        return false
    }
}

@MainActor
final class ShareModel: ObservableObject {
    enum Phase { case loading, ready, sending, done }

    struct Row: Identifiable {
        let id = UUID()
        let link: ParsedLink
        var status: String?
        var ok: Bool?
    }

    @Published var phase: Phase = .loading
    @Published var rows: [Row] = []
    @Published var hasKey = false
    @Published var message: String?

    var close: () -> Void = {}
    var openApp: (URL) -> Bool = { _ in false }
    private var api: TorBoxAPI?

    func load(from items: [NSExtensionItem]) async {
        var collected: [String] = []
        for item in items {
            if let text = item.attributedContentText?.string { collected.append(text) }
            for provider in item.attachments ?? [] {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = try? await provider.loadItem(forTypeIdentifier: UTType.url.identifier) as? URL {
                    collected.append(url.absoluteString)
                } else if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier),
                          let text = try? await provider.loadItem(forTypeIdentifier: UTType.plainText.identifier) as? String {
                    collected.append(text)
                }
            }
        }
        rows = LinkParser.parse(collected.joined(separator: "\n")).links.map { Row(link: $0) }
        if let key = SharedKeychain.load(), !key.isEmpty {
            api = TorBoxAPI(apiKey: key)
            hasKey = true
        }
        // Como compartir en WhatsApp: se abre T-Box con la hoja Agregar y el envío se confirma ahí.
        // Esta pantalla solo queda visible si no se pudo abrir la app.
        if !rows.isEmpty, openInTBox() { return }
        phase = .ready
    }

    func send(onlyIfCached: Bool) async {
        guard let api else { return }
        phase = .sending
        for i in rows.indices {
            do {
                let r: CreateResult
                if rows[i].link.kind == .magnet {
                    r = try await api.addMagnet(rows[i].link.value, onlyIfCached: onlyIfCached)
                } else if rows[i].link.kind == .torrentURL {
                    r = try await api.addTorrentURL(rows[i].link.value, onlyIfCached: onlyIfCached)
                } else {
                    r = try await api.addWebDownload(link: rows[i].link.value, password: nil, name: nil,
                                                     onlyIfCached: onlyIfCached)
                }
                rows[i].ok = true
                rows[i].status = r.queuedID != nil && r.itemID == nil
                    ? L("En cola de TorBox: no hay cupos libres ahora") : (r.message ?? L("Agregado"))
            } catch {
                rows[i].ok = false
                rows[i].status = error.localizedDescription
            }
        }
        phase = .done
    }

    @discardableResult
    func openInTBox() -> Bool {
        let text = rows.map(\.link.original).joined(separator: "\n")
        var comps = URLComponents()
        comps.scheme = "tbox"
        comps.host = "add"
        comps.queryItems = [URLQueryItem(name: "text", value: text)]
        if let url = comps.url, openApp(url) {
            close()
            return true
        }
        UIPasteboard.general.string = text
        message = L("No se pudo abrir T-Box. Copié el enlace: abre T-Box y toca +.")
        return false
    }
}

struct ShareView: View {
    @ObservedObject var model: ShareModel
    @State private var onlyCached = false

    var body: some View {
        NavigationStack {
            List {
                if model.phase == .loading {
                    ProgressView()
                } else if model.rows.isEmpty {
                    Text("No encontré un magnet ni un enlace para TorBox en lo que compartiste.")
                        .foregroundStyle(.secondary)
                } else {
                    Section {
                        ForEach(model.rows) { row in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Image(systemName: row.link.isTorrent ? "link.badge.plus" : "globe")
                                        .foregroundStyle(.green)
                                    Text(row.link.displayName).font(.subheadline.weight(.semibold)).lineLimit(2)
                                    Spacer()
                                    if let ok = row.ok {
                                        Image(systemName: ok ? "checkmark.circle.fill" : "xmark.circle.fill")
                                            .foregroundStyle(ok ? .green : .red)
                                    }
                                }
                                if let s = row.status {
                                    Text(s).font(.caption).foregroundStyle(row.ok == false ? .red : .secondary)
                                }
                            }
                        }
                    } header: {
                        Text(model.rows.count == 1 ? L("Para TorBox") : String(format: L("%d enlaces para TorBox"), model.rows.count))
                    }
                    if model.hasKey && model.phase == .ready {
                        Toggle("Solo si ya está en caché", isOn: $onlyCached)
                    }
                    if !model.hasKey {
                        Section {
                            Text("Para enviar directo desde aquí, abre T-Box una vez con tu sesión iniciada. Si tu firma no lo permite, este botón abre T-Box con el enlace.")
                                .font(.footnote).foregroundStyle(.secondary)
                        }
                    }
                }
                if let m = model.message {
                    Text(m).font(.footnote).foregroundStyle(.orange)
                }
            }
            .navigationTitle("T-Box")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.phase == .done ? L("Listo") : L("Cancelar")) { model.close() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !model.rows.isEmpty && model.phase != .loading {
                    VStack(spacing: 8) {
                        if model.hasKey && model.phase != .done {
                            Button {
                                Task { await model.send(onlyIfCached: onlyCached) }
                            } label: {
                                HStack {
                                    if model.phase == .sending { ProgressView().tint(.black) }
                                    Text(model.phase == .sending ? L("Enviando…") : L("Enviar a TorBox")).font(.headline)
                                }
                                .frame(maxWidth: .infinity).padding(.vertical, 6)
                            }
                            .buttonStyle(.borderedProminent)
                            .disabled(model.phase == .sending)
                        }
                        Button {
                            model.openInTBox()
                        } label: {
                            Text("Abrir en T-Box").frame(maxWidth: .infinity).padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                    }
                    .controlSize(.large)
                    .padding()
                    .background(.bar)
                }
            }
        }
        .tint(.green)
    }
}
