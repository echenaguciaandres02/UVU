import UIKit

/// Vibraciones cortas de confirmación.
@MainActor
enum Haptics {
    static func success() {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
    }

    /// Golpe seco al "estampar" un hábito como completado.
    static func stamp() {
        UIImpactFeedbackGenerator(style: .heavy).impactOccurred()
    }

    static func tap() {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
    }
}
