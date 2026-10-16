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
        populateTasks(context: context, today: today)
    }

    private static func populateTasks(context: ModelContext, today: Date) {
        let calendar = AppCalendar.calendar
        let lists = ((try? context.fetch(FetchDescriptor<TaskList>())) ?? []).sorted { $0.sortOrder < $1.sortOrder }
        guard lists.count >= 3 else { return }
        let (personal, work, university) = (lists[0], lists[1], lists[2])
        let day = AppCalendar.startOfDay(today)

        func at(_ days: Int, _ hour: Int? = nil) -> Date {
            let base = calendar.date(byAdding: .day, value: days, to: day) ?? day
            guard let hour else { return base }
            return calendar.date(bySettingHour: hour, minute: 0, second: 0, of: base) ?? base
        }

        func add(_ title: String, _ list: TaskList, due: Date?, hasTime: Bool = false,
                 priority: TaskItemPriority = .none, recurrence: TaskRecurrence = .none,
                 subtasks: [(String, Bool)] = [], completedDaysAgo: Int? = nil) {
            let task = TaskItem(title: title, dueDate: due, hasTime: hasTime)
            task.priority = priority
            task.recurrence = recurrence
            context.insert(task)
            task.list = list
            for (index, (name, done)) in subtasks.enumerated() {
                let subtask = Subtask(title: name, order: index)
                subtask.isDone = done
                context.insert(subtask)
                subtask.task = task
            }
            if let completedDaysAgo {
                task.isCompleted = true
                task.completedAt = calendar.date(byAdding: .day, value: -completedDaysAgo, to: today)
            }
        }

        add("Pagar la tarjeta", personal, due: at(-1), priority: .high)
        add("Entregar capítulo 3 de la tesis", university, due: at(0, 23), hasTime: true, priority: .high,
            subtasks: [("Revisar bibliografía", true), ("Corregir conclusiones", false), ("Exportar PDF", false)])
        add("Llamar al banco", personal, due: at(0, 16), hasTime: true)
        add("Revisar correos", work, due: at(0), recurrence: .daily)
        add("Reunión de equipo", work, due: at(1, 10), hasTime: true, recurrence: .weekly)
        add("Comprar proteína", personal, due: at(3), priority: .medium)
        add("Inscribir materias", university, due: at(9), priority: .medium)
        add("Ideas para el proyecto", work, due: nil)
        add("Renovar pasaporte", personal, due: nil, priority: .low)
        add("Enviar informe semanal", work, due: at(-1), completedDaysAgo: 0)
        add("Leer paper de metodología", university, due: at(-2), completedDaysAgo: 1)
        try? context.save()
    }
}
#endif
