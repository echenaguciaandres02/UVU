import SwiftUI

extension Color {
    /// Crea un color a partir de un hex de 6 dígitos ("34C759" o "#34C759").
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var value: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&value)

        let red, green, blue: Double
        if cleaned.count == 6 {
            red = Double((value >> 16) & 0xFF) / 255
            green = Double((value >> 8) & 0xFF) / 255
            blue = Double(value & 0xFF) / 255
        } else {
            red = 0.56
            green = 0.56
            blue = 0.58
        }
        self.init(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }
}

/// Paleta de colores para hábitos, listas y rutinas (colores de sistema de iOS).
enum AppPalette {
    static let colors: [String] = [
        "FF3B30", "FF9500", "FFCC00", "34C759", "00C7BE",
        "30B0C7", "007AFF", "5856D6", "AF52DE", "FF2D55", "A2845E",
    ]
}
