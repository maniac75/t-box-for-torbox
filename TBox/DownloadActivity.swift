import ActivityKit
import Foundation

/// Datos de la Live Activity de descargas al iPhone (Dynamic Island y pantalla de bloqueo).
/// Se comparte entre la app, que la crea y actualiza, y la extensión de widgets, que la dibuja.
struct DownloadActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        /// Nombre del archivo, o "3 descargas" si hay varias.
        var title: String
        /// Descargas en curso (0 cuando terminó).
        var count: Int
        /// Avance total, de 0 a 1.
        var progress: Double
        var received: Int64
        var expected: Int64
        var finished: Bool
    }
}
