import SwiftUI
import UIKit

extension Color {
    /// Crea un color a partir de un hex de 6 dígitos ("34C759" o "#34C759").
    /// Solo para colores elegidos por el usuario (hábitos, listas): la interfaz usa los tokens de `Theme`.
    init(hex: String) {
        let (red, green, blue) = Color.components(hex: hex)
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    /// Versión apagada del color de un hábito: misma tonalidad, poca saturación,
    /// para que conviva con la paleta negra/hueso sin competir con el rojo.
    static func muted(hex: String) -> Color {
        let (red, green, blue) = components(hex: hex)
        let base = UIColor(red: red, green: green, blue: blue, alpha: 1)
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard base.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return .ash
        }
        return Color(hue: hue, saturation: min(saturation, 1) * 0.38, brightness: 0.74)
    }

    private static func components(hex: String) -> (Double, Double, Double) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)
        guard cleaned.count == 6 else { return (0.55, 0.55, 0.55) }
        return (Double((value >> 16) & 0xFF) / 255,
                Double((value >> 8) & 0xFF) / 255,
                Double(value & 0xFF) / 255)
    }
}

/// Colores que se pueden asignar a hábitos, listas y rutinas. En pantalla se muestran apagados.
enum AppPalette {
    static let colors: [String] = [
        "FF3B30", "FF9500", "FFCC00", "34C759", "00C7BE",
        "30B0C7", "007AFF", "5856D6", "AF52DE", "FF2D55", "A2845E",
    ]
}
