import Foundation
import SwiftData

/// Operaciones para registrar el avance de un hábito en un día.
@MainActor
enum HabitActions {
    static func entry(for habit: Habit, on date: Date) -> HabitEntry? {
        habit.entries?.first { AppCalendar.calendar.isDate($0.date, inSameDayAs: date) }
    }

    static func value(for habit: Habit, on date: Date) -> Double {
        entry(for: habit, on: date)?.value ?? 0
    }

    static func isCompleted(_ habit: Habit, on date: Date) -> Bool {
        let goal = habit.kind == .binary ? 1 : habit.target
        return value(for: habit, on: date) >= goal
    }

    /// Guarda la cantidad del día. Con 0 se borra el registro.
    static func setValue(_ value: Double, for habit: Habit, on date: Date, in context: ModelContext) {
        let cleanValue = max(0, value)
        if let existing = entry(for: habit, on: date) {
            if cleanValue == 0 {
                existing.habit = nil
                context.delete(existing)
            } else {
                existing.value = cleanValue
            }
        } else if cleanValue > 0 {
            let entry = HabitEntry(date: date, value: cleanValue)
            context.insert(entry)
            entry.habit = habit
        }
        try? context.save()
    }

    /// Marca o desmarca el día como cumplido. Devuelve el nuevo estado.
    @discardableResult
    static func toggle(_ habit: Habit, on date: Date, in context: ModelContext) -> Bool {
        let wasCompleted = isCompleted(habit, on: date)
        let fullValue = habit.kind == .binary ? 1 : habit.target
        setValue(wasCompleted ? 0 : fullValue, for: habit, on: date, in: context)
        return !wasCompleted
    }

    /// Marca como cumplido el hábito con un rol especial (ej. "Ejercicio" al terminar un entreno).
    static func complete(systemRole: String, on date: Date, in context: ModelContext) {
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        guard let habit = habits.first(where: { $0.systemRole == systemRole && !$0.isArchived }),
              !isCompleted(habit, on: date) else { return }
        setValue(habit.kind == .binary ? 1 : habit.target, for: habit, on: date, in: context)
    }
}
