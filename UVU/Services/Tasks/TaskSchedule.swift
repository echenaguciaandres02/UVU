import Foundation

/// Reglas de fechas de las tareas, sin depender de SwiftData (se prueban en `TaskScheduleTests`).
enum TaskSchedule {
    private static var calendar: Calendar { AppCalendar.calendar }

    /// Hora del aviso para tareas con fecha pero sin hora (minutos desde medianoche). Por defecto 9:00.
    static let defaultReminderKey = "tasks.defaultReminderMinutes"
    static var defaultReminderMinutes: Int {
        let stored = UserDefaults.standard.object(forKey: defaultReminderKey) as? Int
        return stored ?? 9 * 60
    }

    // MARK: - Recurrencia

    /// Siguiente fecha límite de una tarea recurrente al completarla.
    /// Avanza desde la fecha anterior (conserva la hora) y salta las ocurrencias ya pasadas:
    /// una tarea diaria atrasada 3 días vuelve a quedar para hoy (o mañana si ya pasó la hora).
    static func nextDueDate(after due: Date, recurrence: TaskRecurrence, hasTime: Bool, now: Date = .now) -> Date? {
        let component: Calendar.Component
        switch recurrence {
        case .none: return nil
        case .daily: component = .day
        case .weekly: component = .weekOfYear
        case .monthly: component = .month
        }

        func isPast(_ date: Date) -> Bool {
            hasTime ? date <= now : AppCalendar.startOfDay(date) < AppCalendar.startOfDay(now)
        }

        // Se suma siempre desde la fecha original: así un mensual del 31 no se "pega" al 28 de febrero.
        var step = 1
        var candidate = calendar.date(byAdding: component, value: step, to: due) ?? due
        while isPast(candidate) && step < 5000 {
            step += 1
            guard let next = calendar.date(byAdding: component, value: step, to: due) else { break }
            candidate = next
        }
        return candidate
    }

    // MARK: - Aviso

    /// Momento en que debe sonar el aviso, o `nil` si no hay que avisar.
    static func reminderDate(due: Date?, hasTime: Bool, reminderEnabled: Bool, offsetMinutes: Int,
                             defaultMinutes: Int = defaultReminderMinutes) -> Date? {
        guard reminderEnabled, let due else { return nil }
        let base: Date
        if hasTime {
            base = due
        } else {
            base = calendar.date(byAdding: .minute, value: defaultMinutes, to: AppCalendar.startOfDay(due)) ?? due
        }
        return calendar.date(byAdding: .minute, value: -offsetMinutes, to: base)
    }

    // MARK: - Estado

    static func isOverdue(due: Date?, hasTime: Bool, isCompleted: Bool, now: Date = .now) -> Bool {
        guard !isCompleted, let due else { return false }
        return hasTime ? due < now : AppCalendar.startOfDay(due) < AppCalendar.startOfDay(now)
    }

    /// Vence hoy o está atrasada (vista "Hoy").
    static func isDueTodayOrOverdue(due: Date?, now: Date = .now) -> Bool {
        guard let due else { return false }
        return AppCalendar.startOfDay(due) <= AppCalendar.startOfDay(now)
    }

    /// Vence después de hoy (vista "Próximos").
    static func isUpcoming(due: Date?, now: Date = .now) -> Bool {
        guard let due else { return false }
        return AppCalendar.startOfDay(due) > AppCalendar.startOfDay(now)
    }

    /// "HOY 15:00", "MAÑANA", "VIE 24 OCT", "AYER".
    static func dueDescription(due: Date, hasTime: Bool, now: Date = .now) -> String {
        let day: String
        if calendar.isDate(due, inSameDayAs: now) {
            day = "Hoy"
        } else if let tomorrow = calendar.date(byAdding: .day, value: 1, to: now), calendar.isDate(due, inSameDayAs: tomorrow) {
            day = "Mañana"
        } else if let yesterday = calendar.date(byAdding: .day, value: -1, to: now), calendar.isDate(due, inSameDayAs: yesterday) {
            day = "Ayer"
        } else {
            let weekday = due.formatted(.dateTime.weekday(.abbreviated).locale(AppLocale.spanish))
            let date = due.formatted(.dateTime.day().month(.abbreviated).locale(AppLocale.spanish))
            day = "\(weekday) \(date)"
        }
        var text = day
        if hasTime {
            text += " " + due.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(AppLocale.spanish))
        }
        return text.replacingOccurrences(of: ".", with: "").uppercased()
    }
}
