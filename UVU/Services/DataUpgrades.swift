import Foundation
import SwiftData

/// Ajustes de datos al abrir la app, para que la información de versiones anteriores
/// se vea bien con las funciones nuevas.
@MainActor
enum DataUpgrades {
    static func run(context: ModelContext) {
        moveLegacyReminders(context: context)
    }

    /// Fase 2 → 2b: el recordatorio único pasa a la lista de recordatorios.
    static func moveLegacyReminders(context: ModelContext) {
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        var changed = false
        for habit in habits {
            guard let hour = habit.reminderHour else { continue }
            let minutes = hour * 60 + (habit.reminderMinute ?? 0)
            if !habit.reminderMinutes.contains(minutes) {
                habit.reminderMinutes = (habit.reminderMinutes + [minutes]).sorted()
            }
            habit.reminderHour = nil
            habit.reminderMinute = nil
            changed = true
        }
        if changed {
            try? context.save()
            Task { await NotificationService.rescheduleAll(context: context) }
        }
    }
}
