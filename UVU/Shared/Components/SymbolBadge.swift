import SwiftUI

/// Ícono del hábito: cuadro `carbon` con borde `graphite` y el SF Symbol en negrita,
/// teñido con el color del hábito apagado (el único rojo con volumen es el de "completado").
struct SymbolBadge: View {
    let symbol: String
    let colorHex: String
    var size: CGFloat = 32

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.sharp, style: .continuous)
        Image(systemName: symbol)
            .font(.system(size: size * 0.46, weight: .bold))
            .foregroundStyle(Color.muted(hex: colorHex))
            .frame(width: size, height: size)
            .background(.carbon, in: shape)
            .overlay { shape.strokeBorder(.graphite, lineWidth: Stroke.hairline) }
            .accessibilityHidden(true)
    }
}

#Preview {
    HStack {
        SymbolBadge(symbol: "drop.fill", colorHex: "007AFF")
        SymbolBadge(symbol: "book.fill", colorHex: "34C759", size: 44)
        SymbolBadge(symbol: "sun.max.fill", colorHex: "FFCC00", size: 44)
    }
    .padding()
    .background(Color.ink)
}
