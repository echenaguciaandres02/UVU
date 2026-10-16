import Foundation

/// Horas del día guardadas como minutos desde medianoche (9:30 → 570).
enum ReminderTime {
    /// Máximo de recordatorios por hábito. iOS solo guarda 64 notificaciones pendientes
    /// para toda la app, así que conviene no gastarlas en un solo hábito.
    static let maxPerHabit = 12

    static func minutes(from date: Date) -> Int {
        let components = AppCalendar.calendar.dateComponents([.hour, .minute], from: date)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    static func date(from minutes: Int) -> Date {
        let components = DateComponents(hour: minutes / 60, minute: minutes % 60)
        return AppCalendar.calendar.date(from: components) ?? .now
    }

    static func format(_ minutes: Int) -> String {
        date(from: minutes).formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(AppLocale.spanish))
    }

    /// Horas repartidas entre `start` y `end` (incluidas) cada `interval` minutos.
    static func spread(from start: Int, to end: Int, every interval: Int) -> [Int] {
        guard interval > 0, start <= end else { return [start] }
        let times = stride(from: start, through: end, by: interval).map { $0 }
        return Array(times.prefix(maxPerHabit))
    }
}
