import SwiftUI
import UIKit

/// Nombres internos (PostScript) de las fuentes incluidas en `Resources/Fonts` (licencia OFL).
enum FontName {
    static let display = "Anton-Regular"
    static let interRegular = "Inter-Regular"
    static let interSemiBold = "Inter-SemiBold"
    static let interBlack = "Inter-Black"
    static let editorialRegular = "CormorantGaramond-Regular"
    static let editorialMedium = "CormorantGaramond-Medium"
    static let editorialItalic = "CormorantGaramond-Italic"

    static let all = [display, interRegular, interSemiBold, interBlack,
                      editorialRegular, editorialMedium, editorialItalic]
}

enum UIWeight {
    case regular
    case semibold
    case black

    var fontName: String {
        switch self {
        case .regular: return FontName.interRegular
        case .semibold: return FontName.interSemiBold
        case .black: return FontName.interBlack
        }
    }
}

// Todas las fuentes usan `relativeTo:` para crecer con el tamaño de texto del sistema (Dynamic Type).
extension Font {
    /// Anton: titulares de pantalla y pósters. Siempre en mayúsculas (usar `.posterTitle()`).
    static func display(_ size: CGFloat, relativeTo style: Font.TextStyle = .largeTitle) -> Font {
        .custom(FontName.display, size: size, relativeTo: style)
    }

    /// Inter: cuerpo, botones y listas.
    static func ui(_ size: CGFloat = 17, _ weight: UIWeight = .regular,
                   relativeTo style: Font.TextStyle = .body) -> Font {
        .custom(weight.fontName, size: size, relativeTo: style)
    }

    /// Cormorant Garamond: frases y momentos "de lujo" (journal, metas a largo plazo).
    static func editorial(_ size: CGFloat = 24, italic: Bool = false,
                          relativeTo style: Font.TextStyle = .title2) -> Font {
        .custom(italic ? FontName.editorialItalic : FontName.editorialRegular, size: size, relativeTo: style)
    }

    /// SF Pro ultraligera, enorme: rachas, horas y contadores (estilo alarma de las 04:00).
    static func numeral(_ size: CGFloat, weight: UIFont.Weight = .ultraLight,
                        relativeTo style: UIFont.TextStyle = .largeTitle) -> Font {
        let base = UIFont.systemFont(ofSize: size, weight: weight)
        return Font(UIFontMetrics(forTextStyle: style).scaledFont(for: base))
    }

    // Estilos de uso frecuente.
    static let uiBody = ui(17, .regular, relativeTo: .body)
    static let uiBodyStrong = ui(17, .semibold, relativeTo: .body)
    static let uiCallout = ui(15, .regular, relativeTo: .callout)
    static let uiFootnote = ui(13, .regular, relativeTo: .footnote)
    static let uiLabel = ui(12, .semibold, relativeTo: .caption)
}

extension View {
    /// Titular de póster: Anton en mayúsculas, tracking apretado.
    func posterTitle(_ size: CGFloat = 56, relativeTo style: Font.TextStyle = .largeTitle) -> some View {
        self
            .font(.display(size, relativeTo: style))
            .textCase(.uppercase)
            .tracking(-0.5)
            .lineLimit(3)
            .minimumScaleFactor(0.6)
            .foregroundStyle(.bone)
    }

    /// Etiqueta pequeña: Inter en mayúsculas con tracking amplio.
    func labelCaps(_ size: CGFloat = 12, _ weight: UIWeight = .semibold, color: Color = .ash) -> some View {
        self
            .font(.ui(size, weight, relativeTo: .caption))
            .textCase(.uppercase)
            .tracking(1.8)
            .foregroundStyle(color)
    }

    /// Frase editorial centrada, con aire.
    func editorialQuote(_ size: CGFloat = 26) -> some View {
        self
            .font(.editorial(size))
            .tracking(1.2)
            .multilineTextAlignment(.center)
            .foregroundStyle(.bone)
    }
}
