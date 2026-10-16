import Foundation

/// Frases de UVU. Edita la lista libremente: agrega las tuyas, una por línea, en mayúsculas,
/// sin emojis ni signos de exclamación. La frase del día rota sola, una distinta cada día.
enum Quotes {
    static let all: [String] = [
        "DO.",
        "SÉ UN HACEDOR.",
        "CADA REPETICIÓN CUENTA.",
        "¿QUIÉN ERES CUANDO NADIE MIRA?",
        "EL AÑO PASADO DIJISTE ESTE AÑO.",
        "1% MEJOR CADA DÍA.",
        "EMPIEZA DONDE ESTÁS.",
    ]

    /// Estado vacío (listas sin contenido).
    static let empty = "NADA REGISTRADO. TODAVÍA."

    /// Al completar todos los hábitos del día.
    static let dayComplete = "HECHO. MAÑANA OTRA VEZ."

    /// La misma frase durante todo el día; cambia a medianoche.
    static func ofTheDay(_ date: Date = .now) -> String {
        guard !all.isEmpty else { return "DO." }
        let day = AppCalendar.calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return all[day % all.count]
    }
}
