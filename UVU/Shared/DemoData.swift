#if DEBUG
import Foundation
import SwiftData

/// Historial de ejemplo para las capturas automáticas (solo desarrollo, base en memoria).
/// Es determinista: siempre produce los mismos días cumplidos, parciales y fallados.
@MainActor
enum DemoData {
    static func populate(context: ModelContext, today: Date = .now) {
        let calendar = AppCalendar.calendar
        let habits = ((try? context.fetch(FetchDescriptor<Habit>())) ?? []).sorted { $0.sortOrder < $1.sortOrder }
        let start = calendar.date(byAdding: .day, value: -45, to: AppCalendar.startOfDay(today)) ?? today

        for (index, habit) in habits.enumerated() {
            habit.createdAt = start
            for offset in 1...45 {
                guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
                let roll = (offset * 7 + index * 3) % 10
                let fullValue = habit.kind == .binary ? 1 : habit.target
                let value: Double
                switch roll {
                case 0, 1: value = 0
                case 2: value = habit.kind == .binary ? 0 : (habit.target / 2).rounded()
                default: value = fullValue
                }
                if value > 0 {
                    HabitActions.setValue(value, for: habit, on: day, in: context)
                }
            }
            // Hoy: los tres primeros hábitos hechos, uno a medias.
            if index < 3 {
                HabitActions.setValue(habit.kind == .binary ? 1 : habit.target, for: habit, on: today, in: context)
            } else if index == 3, habit.kind == .quantity {
                HabitActions.setValue((habit.target / 3).rounded(), for: habit, on: today, in: context)
            }
        }
        try? context.save()
    }
}
#endif
