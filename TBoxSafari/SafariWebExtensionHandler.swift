import Foundation

/// La extensión de Safari no necesita hablar con la app: todo pasa en el navegador
/// y los enlaces llegan a T-Box por tbox://add. Este manejador solo responde vacío.
final class SafariWebExtensionHandler: NSObject, NSExtensionRequestHandling {
    func beginRequest(with context: NSExtensionContext) {
        context.completeRequest(returningItems: [], completionHandler: nil)
    }
}
