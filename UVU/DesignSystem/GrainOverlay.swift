import SwiftUI
import UIKit

/// Textura de ruido generada una sola vez (128×128 en escala de grises) y repetida en mosaico.
/// Determinista: siempre el mismo grano, sin archivos extra en el proyecto.
enum GrainTexture {
    static let image: UIImage = {
        let size = 128
        var pixels = [UInt8](repeating: 0, count: size * size)
        var seed: UInt32 = 0x9E37_79B9
        for index in pixels.indices {
            seed = seed &* 1_664_525 &+ 1_013_904_223
            pixels[index] = UInt8(truncatingIfNeeded: seed >> 24)
        }
        guard let provider = CGDataProvider(data: Data(pixels) as CFData),
              let cgImage = CGImage(
                  width: size, height: size, bitsPerComponent: 8, bitsPerPixel: 8, bytesPerRow: size,
                  space: CGColorSpaceCreateDeviceGray(), bitmapInfo: CGBitmapInfo(rawValue: 0),
                  provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
              )
        else { return UIImage() }
        return UIImage(cgImage: cgImage, scale: 2, orientation: .up)
    }()
}

enum GrainStyle {
    /// Sobre fondos oscuros: puntos casi imperceptibles (3–4 %).
    case subtle
    /// Sobre pósters rojos: fotocopia visible de cerca (6 %).
    case poster

    var opacity: Double {
        switch self {
        case .subtle: return 0.035
        case .poster: return 0.06
        }
    }

    var blendMode: BlendMode {
        switch self {
        case .subtle: return .normal
        case .poster: return .overlay
        }
    }
}

/// Capa de grano de fotocopia. No recibe toques ni la lee VoiceOver.
struct GrainOverlay: View {
    var style: GrainStyle = .subtle

    var body: some View {
        Image(uiImage: GrainTexture.image)
            .resizable(resizingMode: .tile)
            .blendMode(style.blendMode)
            .opacity(style.opacity)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

extension View {
    func grain(_ style: GrainStyle = .subtle) -> some View {
        overlay(GrainOverlay(style: style))
    }
}
