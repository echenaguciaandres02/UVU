import Foundation
import SwiftData

/// Operaciones sobre tareas. Mantienen las notificaciones al día.
@MainActor
enum TaskActions {

    /// Marca la tarea como hecha. Si es recurrente, crea la siguiente ocurrencia (con las subtareas
    /// sin marcar) y la devuelve. La tarea completada queda en "Completadas".
    @discardableResult
    static func complete(_ task: TaskItem, in context: ModelContext, now: Date = .now) -> TaskItem? {
        guard !task.isCompleted else { return nil }
        task.isCompleted = true
        task.completedAt = now
        NotificationService.removeTaskReminders(for: task.id)

        var next: TaskItem?
        if let due = task.dueDate,
           let nextDue = TaskSchedule.nextDueDate(after: due, recurrence: task.recurrence,
                                                  hasTime: task.hasTime, now: now) {
            let copy = TaskItem(title: task.title, notes: task.notes, dueDate: nextDue, hasTime: task.hasTime)
            copy.priorityRaw = task.priorityRaw
            copy.recurrenceRaw = task.recurrenceRaw
            copy.reminderEnabled = task.reminderEnabled
            copy.reminderOffsetMinutes = task.reminderOffsetMinutes
            context.insert(copy)
            copy.list = task.list
            for subtask in task.sortedSubtasks {
                let fresh = Subtask(title: subtask.title, order: subtask.order)
                context.insert(fresh)
                fresh.task = copy
            }
            next = copy
        }

        try? context.save()
        if let next {
            Task { await NotificationService.scheduleTaskReminder(for: next) }
        }
        return next
    }

    /// Vuelve a dejar la tarea pendiente (no borra la ocurrencia siguiente si ya se creó).
    static func reopen(_ task: TaskItem, in context: ModelContext) {
        guard task.isCompleted else { return }
        task.isCompleted = false
        task.completedAt = nil
        try? context.save()
        Task { await NotificationService.scheduleTaskReminder(for: task) }
    }

    static func toggle(_ task: TaskItem, in context: ModelContext) {
        if task.isCompleted {
            reopen(task, in: context)
        } else {
            complete(task, in: context)
        }
    }

    static func delete(_ task: TaskItem, in context: ModelContext) {
        NotificationService.removeTaskReminders(for: task.id)
        context.delete(task)
        try? context.save()
    }

    /// Busca una tarea por id (para las acciones desde la notificación).
    static func task(id: UUID, in context: ModelContext) -> TaskItem? {
        var descriptor = FetchDescriptor<TaskItem>(predicate: #Predicate { $0.id == id })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }
}

/// Agrupaciones de las vistas Hoy / Próximos / Todas / Completadas.
enum TaskScope: String, CaseIterable, Identifiable {
    case today
    case upcoming
    case all
    case completed

    var id: String { rawValue }

    var title: String {
        switch self {
        case .today: return "Hoy"
        case .upcoming: return "Próximos"
        case .all: return "Todas"
        case .completed: return "Hechas"
        }
    }
}

struct TaskSection: Identifiable {
    let id: String
    let title: String
    let tasks: [TaskItem]
    /// Lista de la sección (en Hoy y Todas), para mostrar su ícono y color.
    var list: TaskList? = nil
}

enum TaskGrouping {
    /// Pendientes ordenadas: primero con fecha (la más próxima antes), luego prioridad, luego creación.
    static func sortPending(_ tasks: [TaskItem]) -> [TaskItem] {
        tasks.sorted { lhs, rhs in
            switch (lhs.dueDate, rhs.dueDate) {
            case let (l?, r?) where l != r: return l < r
            case (.some, .none): return true
            case (.none, .some): return false
            default:
                if lhs.priorityRaw != rhs.priorityRaw { return lhs.priorityRaw > rhs.priorityRaw }
                return lhs.createdAt < rhs.createdAt
            }
        }
    }

    /// Una sección por lista, en el orden de las listas; las tareas sin lista al final.
    static func byList(_ tasks: [TaskItem], prefix: String) -> [TaskSection] {
        let grouped = Dictionary(grouping: tasks) { $0.list?.id }
        let lists = Set(tasks.compactMap(\.list)).sorted { ($0.sortOrder, $0.name) < ($1.sortOrder, $1.name) }
        var sections = lists.map { list in
            TaskSection(id: "\(prefix)-list-\(list.id.uuidString)", title: list.name,
                        tasks: sortPending(grouped[list.id] ?? []), list: list)
        }
        if let orphans = grouped[nil], !orphans.isEmpty {
            sections.append(TaskSection(id: "\(prefix)-no-list", title: "Sin lista", tasks: sortPending(orphans)))
        }
        return sections
    }

    static func sections(for scope: TaskScope, tasks: [TaskItem], now: Date = .now) -> [TaskSection] {
        let pending = sortPending(tasks.filter { !$0.isCompleted })
        switch scope {
        case .today:
            // Vencen hoy o están atrasadas, separadas por lista (las atrasadas primero dentro de cada una).
            let due = pending.filter { TaskSchedule.isDueTodayOrOverdue(due: $0.dueDate, now: now) }
            return byList(due, prefix: "today")

        case .upcoming:
            let upcoming = pending.filter { TaskSchedule.isUpcoming(due: $0.dueDate, now: now) }
            let byDay = Dictionary(grouping: upcoming) { AppCalendar.startOfDay($0.dueDate ?? now) }
            return byDay.keys.sorted().map { day in
                TaskSection(id: "day-\(day.timeIntervalSince1970)",
                            title: TaskSchedule.dueDescription(due: day, hasTime: false, now: now),
                            tasks: byDay[day] ?? [])
            }

        case .all:
            return byList(pending, prefix: "all")

        case .completed:
            let done = tasks.filter(\.isCompleted)
                .sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }
            let byDay = Dictionary(grouping: done) { AppCalendar.startOfDay($0.completedAt ?? now) }
            return byDay.keys.sorted(by: >).map { day in
                TaskSection(id: "done-\(day.timeIntervalSince1970)",
                            title: TaskSchedule.dueDescription(due: day, hasTime: false, now: now),
                            tasks: byDay[day] ?? [])
            }
        }
    }
}
