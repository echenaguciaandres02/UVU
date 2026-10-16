import Foundation
import SwiftData

enum HabitKind: String, Codable, CaseIterable, Identifiable {
    case binary
    case quantity

    var id: String { rawValue }

    var title: String {
        switch self {
        case .binary: return "Sí / No"
        case .quantity: return "Cuantitativo"
        }
    }
}

enum HabitFrequency: String, Codable, CaseIterable, Identifiable {
    case daily
    case specificDays
    case timesPerWeek

    var id: String { rawValue }

    var title: String {
        switch self {
        case .daily: return "Diario"
        case .specificDays: return "Días específicos"
        case .timesPerWeek: return "Veces por semana"
        }
    }
}

/// Roles especiales que la app reconoce para automatizar cosas.
enum HabitSystemRole {
    /// Se marca solo al terminar un entreno en el módulo Gym.
    static let exercise = "exercise"
}

// Nota sobre CloudKit: todas las propiedades tienen valor por defecto, todas las
// relaciones son opcionales y no se usa `@Attribute(.unique)`. Así el modelo ya es
// compatible con la sincronización de iCloud cuando se active.

@Model
final class Habit {
    var id: UUID = UUID()
    var name: String = ""
    var symbol: String = "checkmark.circle.fill"
    var colorHex: String = "34C759"
    var kindRaw: String = "binary"
    /// Meta diaria. Para hábitos sí/no siempre es 1.
    var target: Double = 1
    var unit: String = ""
    var frequencyRaw: String = "daily"
    /// Días de la semana en formato de `Calendar` (1 = domingo … 7 = sábado).
    var weekdays: [Int] = []
    var timesPerWeek: Int = 3
    var reminderHour: Int? = nil
    var reminderMinute: Int? = nil
    var systemRole: String? = nil
    var sortOrder: Int = 0
    var isArchived: Bool = false
    var createdAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \HabitEntry.habit)
    var entries: [HabitEntry]? = []

    init(
        name: String,
        symbol: String,
        colorHex: String,
        kind: HabitKind = .binary,
        target: Double = 1,
        unit: String = "",
        frequency: HabitFrequency = .daily,
        sortOrder: Int = 0,
        systemRole: String? = nil
    ) {
        self.name = name
        self.symbol = symbol
        self.colorHex = colorHex
        self.kindRaw = kind.rawValue
        self.target = target
        self.unit = unit
        self.frequencyRaw = frequency.rawValue
        self.sortOrder = sortOrder
        self.systemRole = systemRole
    }

    var kind: HabitKind {
        get { HabitKind(rawValue: kindRaw) ?? .binary }
        set { kindRaw = newValue.rawValue }
    }

    var frequency: HabitFrequency {
        get { HabitFrequency(rawValue: frequencyRaw) ?? .daily }
        set { frequencyRaw = newValue.rawValue }
    }

    var frequencyDescription: String {
        switch frequency {
        case .daily:
            return "Todos los días"
        case .specificDays:
            let names = AppCalendar.orderedWeekdays
                .filter { weekdays.contains($0) }
                .map { AppCalendar.shortWeekdayName($0) }
            return names.isEmpty ? "Ningún día" : names.joined(separator: ", ")
        case .timesPerWeek:
            return timesPerWeek == 1 ? "1 vez por semana" : "\(timesPerWeek) veces por semana"
        }
    }

    var goalDescription: String {
        switch kind {
        case .binary: return "Sí / No"
        case .quantity: return "\(target.formatted()) \(unit)".trimmingCharacters(in: .whitespaces)
        }
    }
}

@Model
final class HabitEntry {
    var id: UUID = UUID()
    /// Inicio del día (00:00) al que corresponde el registro.
    var date: Date = Date()
    /// Para hábitos sí/no: 1 = cumplido. Para cuantitativos: cantidad lograda.
    var value: Double = 0
    var habit: Habit?

    init(date: Date, value: Double) {
        self.date = AppCalendar.startOfDay(date)
        self.value = value
    }
}
