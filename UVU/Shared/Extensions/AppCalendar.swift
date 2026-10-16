import Foundation

enum AppLocale {
    static let spanish = Locale(identifier: "es")
}

/// Calendario único de la app: gregoriano, en español y con la semana empezando el lunes.
enum AppCalendar {
    static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = AppLocale.spanish
        calendar.firstWeekday = 2
        return calendar
    }()

    /// Días de la semana (formato `Calendar`) ordenados de lunes a domingo.
    static let orderedWeekdays = [2, 3, 4, 5, 6, 7, 1]

    static func startOfDay(_ date: Date) -> Date {
        calendar.startOfDay(for: date)
    }

    static func weekday(of date: Date) -> Int {
        calendar.component(.weekday, from: date)
    }

    /// "lun", "mar", …
    static func shortWeekdayName(_ weekday: Int) -> String {
        calendar.shortWeekdaySymbols[weekday - 1]
    }

    /// "L", "M", …
    static func veryShortWeekdayName(_ weekday: Int) -> String {
        calendar.veryShortWeekdaySymbols[weekday - 1]
    }
}

extension String {
    var capitalizedFirst: String {
        prefix(1).uppercased() + dropFirst()
    }
}
