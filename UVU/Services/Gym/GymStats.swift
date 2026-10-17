import Foundation

/// Cálculos del gym, sin depender de SwiftData (se prueban en `GymTests`).
enum GymMath {
    /// 1RM estimado con la fórmula de Epley: peso × (1 + reps / 30). Con 1 repetición es el propio peso.
    static func estimatedOneRepMax(weight: Double, reps: Int) -> Double {
        guard weight > 0, reps > 0 else { return 0 }
        if reps == 1 { return weight }
        return weight * (1 + Double(reps) / 30)
    }

    /// "62,5 kg", "135 lb"
    static func format(_ weight: Double, unit: WeightUnit) -> String {
        "\(NumberText.format((weight * 10).rounded() / 10)) \(unit.rawValue)"
    }

    /// "1:05:12" o "48:03"
    static func duration(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        return hours > 0 ? String(format: "%d:%02d:%02d", hours, minutes, secs) : String(format: "%d:%02d", minutes, secs)
    }
}

/// Resumen de un ejercicio en una sesión terminada, en la unidad que se pida.
struct ExerciseSessionStat: Identifiable, Equatable {
    let sessionID: UUID
    let date: Date
    let maxWeight: Double
    let bestOneRepMax: Double
    let volume: Double
    let sets: Int

    var id: UUID { sessionID }
}

/// Récords de un ejercicio.
struct ExerciseRecords: Equatable {
    var maxWeight: Double = 0
    var maxWeightDate: Date?
    var bestOneRepMax: Double = 0
    var bestOneRepMaxDate: Date?
}

/// Una serie reducida a lo que importa para estadísticas (permite probar sin SwiftData).
struct SetSample: Equatable {
    var weight: Double
    var unit: WeightUnit
    var reps: Int
}

enum ExerciseStatsCalculator {
    static func stat(sessionID: UUID, date: Date, sets: [SetSample], unit: WeightUnit) -> ExerciseSessionStat? {
        let valid = sets.filter { $0.reps > 0 }
        guard !valid.isEmpty else { return nil }
        let weights = valid.map { $0.unit.convert($0.weight, to: unit) }
        let oneRepMaxes = zip(valid, weights).map { GymMath.estimatedOneRepMax(weight: $1, reps: $0.reps) }
        let volume = zip(valid, weights).reduce(0) { $0 + $1.1 * Double($1.0.reps) }
        return ExerciseSessionStat(sessionID: sessionID, date: date, maxWeight: weights.max() ?? 0,
                                   bestOneRepMax: oneRepMaxes.max() ?? 0, volume: volume, sets: valid.count)
    }

    static func records(_ stats: [ExerciseSessionStat]) -> ExerciseRecords {
        var records = ExerciseRecords()
        for stat in stats.sorted(by: { $0.date < $1.date }) {
            if stat.maxWeight > records.maxWeight + 0.0001 {
                records.maxWeight = stat.maxWeight
                records.maxWeightDate = stat.date
            }
            if stat.bestOneRepMax > records.bestOneRepMax + 0.0001 {
                records.bestOneRepMax = stat.bestOneRepMax
                records.bestOneRepMaxDate = stat.date
            }
        }
        return records
    }

    /// ¿Esta sesión superó lo mejor de las sesiones anteriores? (La primera vez no cuenta como récord.)
    static func isRecord(_ stat: ExerciseSessionStat, previous: [ExerciseSessionStat]) -> (weight: Bool, oneRepMax: Bool) {
        let earlier = previous.filter { $0.date < stat.date }
        guard !earlier.isEmpty else { return (false, false) }
        let bestWeight = earlier.map(\.maxWeight).max() ?? 0
        let best1RM = earlier.map(\.bestOneRepMax).max() ?? 0
        return (stat.maxWeight > bestWeight + 0.0001, stat.bestOneRepMax > best1RM + 0.0001)
    }
}
