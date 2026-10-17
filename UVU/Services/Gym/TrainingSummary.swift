import Foundation

/// Una serie hecha, reducida a lo que usa el resumen (permite probar sin SwiftData).
struct TrainingSet: Equatable {
    var date: Date
    var muscle: MuscleGroup
    var exerciseID: UUID
    var exerciseName: String
    /// Peso ya convertido a la unidad del resumen.
    var weight: Double
    var reps: Int
}

/// Reparto del trabajo de un grupo muscular en un periodo.
struct MuscleShare: Identifiable, Equatable {
    let muscle: MuscleGroup
    /// Series hechas en el periodo (cada serie cuenta 1 para el músculo principal del ejercicio).
    let sets: Int
    /// Fracción del total del periodo (0…1).
    let fraction: Double
    /// Series del periodo anterior (mes o año anterior), para comparar.
    let previousSets: Int

    var id: MuscleGroup { muscle }

    /// Cambio frente al periodo anterior en %, o `nil` si antes no había nada.
    var change: Double? {
        guard previousSets > 0 else { return nil }
        return Double(sets - previousSets) / Double(previousSets)
    }
}

/// Mejora de un ejercicio en un periodo frente a todo lo anterior.
struct ExerciseProgress: Identifiable, Equatable {
    let exerciseID: UUID
    let name: String
    let muscle: MuscleGroup
    /// Mejor peso del periodo y cuánto supera al mejor anterior (`nil` si no lo superó).
    let bestWeight: Double
    let weightGain: Double?
    /// Mejor 1RM estimado del periodo y cuánto supera al mejor anterior.
    let bestOneRepMax: Double
    let oneRepMaxGain: Double?

    var id: UUID { exerciseID }
}

/// Series por mes de un año (para la gráfica de barras).
struct MonthTotal: Identifiable, Equatable {
    let month: Date
    let sets: Int

    var id: Date { month }
}

enum SummaryPeriod: String, CaseIterable, Identifiable {
    case month
    case year

    var id: String { rawValue }

    var title: String {
        switch self {
        case .month: return "Mes"
        case .year: return "Año"
        }
    }

    var component: Calendar.Component {
        switch self {
        case .month: return .month
        case .year: return .year
        }
    }
}

/// Resumen del gym por grupo muscular: reparto del mes o del año acumulado, comparación con el
/// periodo anterior, récords y series por mes. El mes empieza de cero cada día 1 y el año suma
/// todos sus meses. Lógica pura: se prueba en `TrainingSummaryTests`.
enum TrainingSummary {
    private static var calendar: Calendar { AppCalendar.calendar }

    static func interval(_ period: SummaryPeriod, containing date: Date) -> DateInterval {
        calendar.dateInterval(of: period.component, for: date) ?? DateInterval(start: date, duration: 86_400)
    }

    static func previousInterval(_ period: SummaryPeriod, before date: Date) -> DateInterval {
        let current = interval(period, containing: date)
        let previousDay = current.start.addingTimeInterval(-1)
        return interval(period, containing: previousDay)
    }

    /// Reparto por grupo muscular, de mayor a menor. Incluye músculos que solo se trabajaron en el
    /// periodo anterior (con 0 series ahora) para que se vea la caída.
    static func shares(_ sets: [TrainingSet], period: SummaryPeriod, containing date: Date) -> [MuscleShare] {
        let current = interval(period, containing: date)
        let previous = previousInterval(period, before: date)
        let now = counts(sets, in: current)
        let before = counts(sets, in: previous)
        let total = now.values.reduce(0, +)
        let muscles = Set(now.keys).union(before.keys)
        return muscles.map { muscle in
            let count = now[muscle] ?? 0
            return MuscleShare(muscle: muscle, sets: count,
                               fraction: total == 0 ? 0 : Double(count) / Double(total),
                               previousSets: before[muscle] ?? 0)
        }
        .sorted { ($0.sets, $0.previousSets, $1.muscle.title) > ($1.sets, $1.previousSets, $0.muscle.title) }
    }

    static func totalSets(_ sets: [TrainingSet], period: SummaryPeriod, containing date: Date) -> Int {
        counts(sets, in: interval(period, containing: date)).values.reduce(0, +)
    }

    /// Los 12 meses del año de `date`, con las series de cada uno.
    static func monthlyTotals(_ sets: [TrainingSet], year date: Date) -> [MonthTotal] {
        let year = interval(.year, containing: date)
        return (0..<12).compactMap { offset in
            guard let month = calendar.date(byAdding: .month, value: offset, to: year.start) else { return nil }
            let count = counts(sets, in: interval(.month, containing: month)).values.reduce(0, +)
            return MonthTotal(month: month, sets: count)
        }
    }

    /// Ejercicios que en el periodo superaron su mejor peso o su mejor 1RM de antes del periodo.
    /// La primera vez que se hace un ejercicio no cuenta como progreso.
    static func progress(_ sets: [TrainingSet], period: SummaryPeriod, containing date: Date) -> [ExerciseProgress] {
        let current = interval(period, containing: date)
        let byExercise = Dictionary(grouping: sets) { $0.exerciseID }
        var result: [ExerciseProgress] = []

        for (id, all) in byExercise {
            let inPeriod = all.filter { current.contains($0.date) && $0.date < current.end && $0.reps > 0 }
            let before = all.filter { $0.date < current.start && $0.reps > 0 }
            guard let sample = inPeriod.first, !before.isEmpty else { continue }

            let bestWeight = inPeriod.map(\.weight).max() ?? 0
            let best1RM = inPeriod.map { GymMath.estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }.max() ?? 0
            let previousWeight = before.map(\.weight).max() ?? 0
            let previous1RM = before.map { GymMath.estimatedOneRepMax(weight: $0.weight, reps: $0.reps) }.max() ?? 0

            let weightGain = bestWeight > previousWeight + 0.0001 ? bestWeight - previousWeight : nil
            let oneRepMaxGain = best1RM > previous1RM + 0.0001 ? best1RM - previous1RM : nil
            guard weightGain != nil || oneRepMaxGain != nil else { continue }

            result.append(ExerciseProgress(exerciseID: id, name: sample.exerciseName, muscle: sample.muscle,
                                           bestWeight: bestWeight, weightGain: weightGain,
                                           bestOneRepMax: best1RM, oneRepMaxGain: oneRepMaxGain))
        }
        return result.sorted { ($0.muscle.title, $0.name) < ($1.muscle.title, $1.name) }
    }

    private static func counts(_ sets: [TrainingSet], in interval: DateInterval) -> [MuscleGroup: Int] {
        var result: [MuscleGroup: Int] = [:]
        for set in sets where set.reps > 0 && set.date >= interval.start && set.date < interval.end {
            result[set.muscle, default: 0] += 1
        }
        return result
    }
}

extension TrainingSummary {
    /// Series hechas de los entrenos terminados, con el peso en `unit`.
    @MainActor
    static func sets(from sessions: [WorkoutSession], unit: WeightUnit) -> [TrainingSet] {
        var result: [TrainingSet] = []
        for session in sessions where !session.isActive {
            for item in session.exercises ?? [] {
                guard let exercise = item.exercise else { continue }
                for set in item.sets ?? [] where set.isCompleted && set.reps > 0 {
                    result.append(TrainingSet(date: session.startedAt, muscle: exercise.muscleGroup,
                                              exerciseID: exercise.id, exerciseName: exercise.name,
                                              weight: set.weight(in: unit), reps: set.reps))
                }
            }
        }
        return result
    }
}
