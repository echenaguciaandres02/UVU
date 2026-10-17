import Foundation

/// Un aviso que todavía va a sonar hoy (pantalla Hoy → "Próximos avisos").
struct AgendaReminder: Identifiable, Equatable {
    enum Kind: Equatable {
        case habit
        case task
    }

    let id: String
    let date: Date
    let title: String
    let symbol: String
    let colorHex: String
    let kind: Kind
}

/// Lógica de la pantalla Hoy, separada de las vistas para poder probarla (`TodayAgendaTests`).
@MainActor
enum TodayAgenda {
    private static var calendar: Calendar { AppCalendar.calendar }

    /// Avisos que quedan hoy desde `now`, en orden de hora: los recordatorios de los hábitos que tocan
    /// hoy y no están cumplidos, y los avisos de las tareas pendientes.
    static func upcomingReminders(habits: [Habit], tasks: [TaskItem], now: Date = .now,
                                  defaultTaskMinutes: Int = TaskSchedule.defaultReminderMinutes) -> [AgendaReminder] {
        let startOfDay = AppCalendar.startOfDay(now)
        guard let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) else { return [] }
        var result: [AgendaReminder] = []

        for habit in habits where !habit.isArchived {
            let evaluator = HabitEvaluator(habit: habit)
            guard evaluator.isScheduled(on: now), !HabitActions.isCompleted(habit, on: now) else { continue }
            for minutes in habit.reminderMinutes {
                guard let date = calendar.date(byAdding: .minute, value: minutes, to: startOfDay),
                      date > now, date < endOfDay else { continue }
                result.append(AgendaReminder(id: "habit-\(habit.id.uuidString)-\(minutes)", date: date,
                                             title: habit.name, symbol: habit.symbol,
                                             colorHex: habit.colorHex, kind: .habit))
            }
        }

        for task in tasks where !task.isCompleted {
            guard let date = TaskSchedule.reminderDate(due: task.dueDate, hasTime: task.hasTime,
                                                       reminderEnabled: task.reminderEnabled,
                                                       offsetMinutes: task.reminderOffsetMinutes,
                                                       defaultMinutes: defaultTaskMinutes),
                  date > now, date < endOfDay else { continue }
            result.append(AgendaReminder(id: "task-\(task.id.uuidString)", date: date, title: task.title,
                                         symbol: task.list?.symbol ?? "checklist",
                                         colorHex: task.list?.colorHex ?? "8C8C8C", kind: .task))
        }

        return result.sorted { ($0.date, $0.title) < ($1.date, $1.title) }
    }

    /// Hábitos que tocan hoy: primero los pendientes y después los hechos, cada grupo en su orden.
    static func todayHabits(_ habits: [Habit], now: Date = .now) -> [Habit] {
        let scheduled = habits.filter { !$0.isArchived && HabitEvaluator(habit: $0).isScheduled(on: now) }
        let pending = scheduled.filter { !HabitActions.isCompleted($0, on: now) }
        let done = scheduled.filter { HabitActions.isCompleted($0, on: now) }
        return pending + done
    }

    /// Tareas pendientes que vencen hoy o están atrasadas, en el orden de la pestaña Tareas.
    static func todayTasks(_ tasks: [TaskItem], now: Date = .now) -> [TaskItem] {
        TaskGrouping.sortPending(tasks.filter {
            !$0.isCompleted && TaskSchedule.isDueTodayOrOverdue(due: $0.dueDate, now: now)
        })
    }
}

/// Lo que pasó cada día, para el calendario unificado: entrenos terminados, tareas completadas y
/// entradas del journal, agrupados por día una sola vez (no se recorre todo en cada celda).
@MainActor
struct DayActivityIndex {
    private(set) var workouts: [Date: [WorkoutSession]] = [:]
    private(set) var completedTasks: [Date: [TaskItem]] = [:]
    private(set) var journal: [Date: JournalEntry] = [:]

    init(sessions: [WorkoutSession], tasks: [TaskItem], entries: [JournalEntry]) {
        for session in sessions where !session.isActive {
            workouts[AppCalendar.startOfDay(session.startedAt), default: []].append(session)
        }
        for task in tasks where task.isCompleted {
            guard let completedAt = task.completedAt else { continue }
            completedTasks[AppCalendar.startOfDay(completedAt), default: []].append(task)
        }
        for entry in entries {
            journal[AppCalendar.startOfDay(entry.date)] = entry
        }
    }

    func workouts(on day: Date) -> [WorkoutSession] {
        (workouts[AppCalendar.startOfDay(day)] ?? []).sorted { $0.startedAt < $1.startedAt }
    }

    func completedTasks(on day: Date) -> [TaskItem] {
        (completedTasks[AppCalendar.startOfDay(day)] ?? [])
            .sorted { ($0.completedAt ?? .distantPast) < ($1.completedAt ?? .distantPast) }
    }

    func journalEntry(on day: Date) -> JournalEntry? {
        journal[AppCalendar.startOfDay(day)]
    }
}
