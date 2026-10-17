import Foundation
import SwiftData

enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest
    case back
    case legs
    case glutes
    case shoulders
    case biceps
    case triceps
    case core
    case cardio
    case other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .chest: return "Pecho"
        case .back: return "Espalda"
        case .legs: return "Piernas"
        case .glutes: return "Glúteos"
        case .shoulders: return "Hombros"
        case .biceps: return "Bíceps"
        case .triceps: return "Tríceps"
        case .core: return "Core"
        case .cardio: return "Cardio"
        case .other: return "Otros"
        }
    }
}

enum WeightUnit: String, Codable, CaseIterable, Identifiable {
    case kg
    case lb

    var id: String { rawValue }

    var title: String { rawValue }

    static let poundsPerKilogram = 2.20462262185

    /// Convierte `value` (expresado en `self`) a `unit`.
    func convert(_ value: Double, to unit: WeightUnit) -> Double {
        switch (self, unit) {
        case (.kg, .lb): return value * Self.poundsPerKilogram
        case (.lb, .kg): return value / Self.poundsPerKilogram
        default: return value
        }
    }
}

@Model
final class Exercise {
    var id: UUID = UUID()
    var name: String = ""
    var muscleRaw: String = "other"
    var equipment: String = ""
    var isCustom: Bool = false
    var notes: String = ""
    var createdAt: Date = Date()

    @Relationship(deleteRule: .nullify, inverse: \RoutineExercise.exercise)
    var routineItems: [RoutineExercise]? = []

    @Relationship(deleteRule: .nullify, inverse: \SessionExercise.exercise)
    var sessionItems: [SessionExercise]? = []

    init(name: String, muscle: MuscleGroup, equipment: String = "", isCustom: Bool = false) {
        self.name = name
        self.muscleRaw = muscle.rawValue
        self.equipment = equipment
        self.isCustom = isCustom
    }

    var muscleGroup: MuscleGroup {
        get { MuscleGroup(rawValue: muscleRaw) ?? .other }
        set { muscleRaw = newValue.rawValue }
    }
}

/// Plantilla de entreno (ej. Push, Pull, Legs).
@Model
final class Routine {
    var id: UUID = UUID()
    var name: String = ""
    /// Días asignados en formato de `Calendar` (1 = domingo … 7 = sábado).
    var weekdays: [Int] = []
    var colorHex: String = "FF9500"
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \RoutineExercise.routine)
    var items: [RoutineExercise]? = []

    @Relationship(deleteRule: .nullify, inverse: \WorkoutSession.routine)
    var sessions: [WorkoutSession]? = []

    init(name: String, weekdays: [Int] = [], colorHex: String = "FF9500", sortOrder: Int = 0) {
        self.name = name
        self.weekdays = weekdays
        self.colorHex = colorHex
        self.sortOrder = sortOrder
    }
}

@Model
final class RoutineExercise {
    var id: UUID = UUID()
    var order: Int = 0
    var targetSets: Int = 3
    var targetReps: Int = 10
    /// Descanso entre series en segundos (fase 5).
    var restSeconds: Int = 90
    var routine: Routine?
    var exercise: Exercise?

    init(order: Int, targetSets: Int = 3, targetReps: Int = 10) {
        self.order = order
        self.targetSets = targetSets
        self.targetReps = targetReps
    }
}

@Model
final class WorkoutSession {
    var id: UUID = UUID()
    var startedAt: Date = Date()
    /// `nil` mientras la sesión está en curso.
    var endedAt: Date? = nil
    var notes: String = ""
    var routine: Routine?

    @Relationship(deleteRule: .cascade, inverse: \SessionExercise.session)
    var exercises: [SessionExercise]? = []

    init(startedAt: Date = Date()) {
        self.startedAt = startedAt
    }
}

@Model
final class SessionExercise {
    var id: UUID = UUID()
    var order: Int = 0
    /// Descanso entre series en segundos, copiado de la rutina al empezar (fase 5).
    var restSeconds: Int = 90
    var session: WorkoutSession?
    var exercise: Exercise?

    @Relationship(deleteRule: .cascade, inverse: \WorkoutSet.sessionExercise)
    var sets: [WorkoutSet]? = []

    init(order: Int) {
        self.order = order
    }
}

@Model
final class WorkoutSet {
    var id: UUID = UUID()
    var order: Int = 0
    /// Peso tal como se escribió, en la unidad `unitRaw` (no se convierte al guardar).
    var weight: Double = 0
    var unitRaw: String = "kg"
    var reps: Int = 0
    var rpe: Double? = nil
    var isCompleted: Bool = false
    var completedAt: Date? = nil
    var sessionExercise: SessionExercise?

    init(order: Int, weight: Double = 0, unit: WeightUnit = .kg, reps: Int = 0) {
        self.order = order
        self.weight = weight
        self.unitRaw = unit.rawValue
        self.reps = reps
    }

    var unit: WeightUnit {
        get { WeightUnit(rawValue: unitRaw) ?? .kg }
        set { unitRaw = newValue.rawValue }
    }

    func weight(in target: WeightUnit) -> Double {
        unit.convert(weight, to: target)
    }
}

extension Routine {
    var sortedItems: [RoutineExercise] {
        (items ?? []).sorted { $0.order < $1.order }
    }

    /// "lun · mié · vie"
    var weekdaysDescription: String {
        let names = AppCalendar.orderedWeekdays.filter { weekdays.contains($0) }
            .map { AppCalendar.shortWeekdayName($0).replacingOccurrences(of: ".", with: "") }
        return names.isEmpty ? "Sin días" : names.joined(separator: " · ")
    }
}

extension WorkoutSession {
    var sortedExercises: [SessionExercise] {
        (exercises ?? []).sorted { $0.order < $1.order }
    }

    var isActive: Bool { endedAt == nil }
}

extension SessionExercise {
    var sortedSets: [WorkoutSet] {
        (sets ?? []).sorted { $0.order < $1.order }
    }

    var completedSets: [WorkoutSet] {
        sortedSets.filter(\.isCompleted)
    }
}
