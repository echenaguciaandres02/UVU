import Foundation

// Formato del respaldo JSON. Son copias planas de los modelos: las relaciones
// se guardan anidadas (ej. hábitos con sus registros) o por id (ej. ejercicio).
// Si el formato cambia, se sube `currentVersion` y se mantiene la lectura de las anteriores.

struct BackupFile: Codable, Equatable {
    static let currentVersion = 1

    var app: String = "UVU"
    var version: Int
    var exportedAt: Date
    var habits: [HabitDTO]
    var taskLists: [TaskListDTO]
    var journalEntries: [JournalEntryDTO]
    var exercises: [ExerciseDTO]
    var routines: [RoutineDTO]
    var sessions: [WorkoutSessionDTO]

    var summary: String {
        let tasks = taskLists.reduce(0) { $0 + $1.tasks.count }
        return """
        Hábitos: \(habits.count)
        Tareas: \(tasks)
        Entradas de journal: \(journalEntries.count)
        Sesiones de gym: \(sessions.count)
        """
    }
}

struct HabitDTO: Codable, Equatable {
    var id: UUID
    var name: String
    var symbol: String
    var colorHex: String
    var kind: String
    var target: Double
    var unit: String
    var frequency: String
    var weekdays: [Int]
    var timesPerWeek: Int
    /// Desde la fase 2b. Opcional para poder leer respaldos anteriores.
    var reminderMinutes: [Int]?
    /// Formato de la fase 1–2 (un solo recordatorio).
    var reminderHour: Int?
    var reminderMinute: Int?
    var systemRole: String?
    var sortOrder: Int
    var isArchived: Bool
    var createdAt: Date
    var entries: [HabitEntryDTO]
}

struct HabitEntryDTO: Codable, Equatable {
    var date: Date
    var value: Double
}

struct TaskListDTO: Codable, Equatable {
    var id: UUID
    var name: String
    var symbol: String
    var colorHex: String
    var sortOrder: Int
    var createdAt: Date
    var tasks: [TaskItemDTO]
}

struct TaskItemDTO: Codable, Equatable {
    var id: UUID
    var title: String
    var notes: String
    var dueDate: Date?
    var hasTime: Bool
    var priority: Int
    var recurrence: String
    var isCompleted: Bool
    var completedAt: Date?
    var createdAt: Date
    var subtasks: [SubtaskDTO]
}

struct SubtaskDTO: Codable, Equatable {
    var title: String
    var isDone: Bool
    var order: Int
}

struct JournalEntryDTO: Codable, Equatable {
    var id: UUID
    var date: Date
    var text: String
    var mood: Int
    var createdAt: Date
    var updatedAt: Date
    var tags: [String]
    var answers: [PromptAnswerDTO]
}

struct PromptAnswerDTO: Codable, Equatable {
    var question: String
    var answer: String
    var order: Int
}

struct ExerciseDTO: Codable, Equatable {
    var id: UUID
    var name: String
    var muscleGroup: String
    var equipment: String
    var isCustom: Bool
    var notes: String
    var createdAt: Date
}

struct RoutineDTO: Codable, Equatable {
    var id: UUID
    var name: String
    var weekdays: [Int]
    var colorHex: String
    var sortOrder: Int
    var createdAt: Date
    var items: [RoutineExerciseDTO]
}

struct RoutineExerciseDTO: Codable, Equatable {
    var order: Int
    var targetSets: Int
    var targetReps: Int
    var exerciseID: UUID?
}

struct WorkoutSessionDTO: Codable, Equatable {
    var id: UUID
    var startedAt: Date
    var endedAt: Date?
    var notes: String
    var routineID: UUID?
    var exercises: [SessionExerciseDTO]
}

struct SessionExerciseDTO: Codable, Equatable {
    var order: Int
    var exerciseID: UUID?
    var sets: [WorkoutSetDTO]
}

struct WorkoutSetDTO: Codable, Equatable {
    var order: Int
    var weight: Double
    var unit: String
    var reps: Int
    var rpe: Double?
    var isCompleted: Bool
    var completedAt: Date?
}
