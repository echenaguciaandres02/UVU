import Foundation
import SwiftData

// Se llama `TaskItemPriority` para no chocar con `TaskPriority` de Swift Concurrency.
enum TaskItemPriority: Int, Codable, CaseIterable, Identifiable {
    case none = 0
    case low = 1
    case medium = 2
    case high = 3

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .none: return "Ninguna"
        case .low: return "Baja"
        case .medium: return "Media"
        case .high: return "Alta"
        }
    }
}

enum TaskRecurrence: String, Codable, CaseIterable, Identifiable {
    case none
    case daily
    case weekly
    case monthly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .none: return "No se repite"
        case .daily: return "Diaria"
        case .weekly: return "Semanal"
        case .monthly: return "Mensual"
        }
    }
}

@Model
final class TaskList {
    var id: UUID = UUID()
    var name: String = ""
    var symbol: String = "list.bullet"
    var colorHex: String = "007AFF"
    var sortOrder: Int = 0
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \TaskItem.list)
    var tasks: [TaskItem]? = []

    init(name: String, symbol: String, colorHex: String, sortOrder: Int = 0) {
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.sortOrder = sortOrder
    }

    var pendingCount: Int {
        (tasks ?? []).filter { !$0.isCompleted }.count
    }
}

@Model
final class TaskItem {
    var id: UUID = UUID()
    var title: String = ""
    var notes: String = ""
    var dueDate: Date? = nil
    /// Si es `false`, solo importa el día de `dueDate`, no la hora.
    var hasTime: Bool = false
    var priorityRaw: Int = 0
    var recurrenceRaw: String = "none"
    var isCompleted: Bool = false
    var completedAt: Date? = nil
    var createdAt: Date = Date()
    /// Si la tarea con fecha avisa con una notificación (fase 3).
    var reminderEnabled: Bool = true
    /// Minutos de anticipación del aviso (0 = a la hora límite).
    var reminderOffsetMinutes: Int = 0
    var list: TaskList?

    @Relationship(deleteRule: .cascade, inverse: \Subtask.task)
    var subtasks: [Subtask]? = []

    init(title: String, notes: String = "", dueDate: Date? = nil, hasTime: Bool = false) {
        self.title = title
        self.notes = notes
        self.dueDate = dueDate
        self.hasTime = hasTime
    }

    var priority: TaskItemPriority {
        get { TaskItemPriority(rawValue: priorityRaw) ?? .none }
        set { priorityRaw = newValue.rawValue }
    }

    var recurrence: TaskRecurrence {
        get { TaskRecurrence(rawValue: recurrenceRaw) ?? .none }
        set { recurrenceRaw = newValue.rawValue }
    }

    var sortedSubtasks: [Subtask] {
        (subtasks ?? []).sorted { ($0.order, $0.title) < ($1.order, $1.title) }
    }

    /// "2/5" si tiene subtareas.
    var subtaskProgress: String? {
        let all = subtasks ?? []
        guard !all.isEmpty else { return nil }
        return "\(all.filter(\.isDone).count)/\(all.count)"
    }
}

/// Anticipación del aviso de una tarea.
enum ReminderOffset: Int, CaseIterable, Identifiable {
    case atTime = 0
    case fiveMinutes = 5
    case fifteenMinutes = 15
    case thirtyMinutes = 30
    case oneHour = 60
    case oneDay = 1440

    var id: Int { rawValue }

    var title: String {
        switch self {
        case .atTime: return "A la hora"
        case .fiveMinutes: return "5 min antes"
        case .fifteenMinutes: return "15 min antes"
        case .thirtyMinutes: return "30 min antes"
        case .oneHour: return "1 hora antes"
        case .oneDay: return "1 día antes"
        }
    }
}

@Model
final class Subtask {
    var id: UUID = UUID()
    var title: String = ""
    var isDone: Bool = false
    var order: Int = 0
    var task: TaskItem?

    init(title: String, order: Int = 0) {
        self.title = title
        self.order = order
    }
}
