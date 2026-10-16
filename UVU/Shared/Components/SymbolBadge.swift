import SwiftUI

/// Ícono SF Symbol blanco sobre un cuadrado redondeado de color (estilo Ajustes de iOS).
struct SymbolBadge: View {
    let symbol: String
    let colorHex: String
    var size: CGFloat = 32

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.5, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(Color(hex: colorHex), in: RoundedRectangle(cornerRadius: size * 0.25, style: .continuous))
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        SymbolBadge(symbol: "drop.fill", colorHex: "007AFF")
        SymbolBadge(symbol: "book.fill", colorHex: "34C759", size: 44)
    }
}
