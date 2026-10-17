import ActivityKit
import Foundation

/// Live Activity del descanso entre series. La comparten la app (que la inicia y actualiza) y la
/// extensión UVUWidgets (que la dibuja en la pantalla de bloqueo y la Dynamic Island).
/// La cuenta atrás la anima el sistema con `Text(timerInterval:)`: no hace falta actualizarla
/// cada segundo, así sigue corriendo con el teléfono bloqueado.
struct RestActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var startDate: Date
        var endDate: Date
        /// Ejercicio de la siguiente serie.
        var exerciseName: String
        /// "Serie 2 de 4"
        var nextSet: String
    }

    /// Rutina del entreno ("Push", "Entreno libre").
    var workoutName: String
}
