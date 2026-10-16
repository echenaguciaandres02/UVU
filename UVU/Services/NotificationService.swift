import Foundation
import SwiftData
import UserNotifications

/// Programa las notificaciones locales de la app.
@MainActor
enum NotificationService {
    private static var center: UNUserNotificationCenter { .current() }

    /// Pide permiso la primera vez. Devuelve si se pueden enviar notificaciones.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        let settings = await center.notificationSettings()
        switch settings.authorizationStatus {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        default:
            return (try? await center.requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        }
    }

    // MARK: - Hábitos

    private static func habitIdentifiers(_ id: UUID) -> [String] {
        ["habit-\(id.uuidString)-daily"] + (1...7).map { "habit-\(id.uuidString)-wd\($0)" }
    }

    static func removeHabitReminders(for id: UUID) {
        center.removePendingNotificationRequests(withIdentifiers: habitIdentifiers(id))
    }

    /// Reemplaza el recordatorio del hábito según su hora y frecuencia actuales.
    static func scheduleHabitReminder(for habit: Habit) async {
        let id = habit.id
        removeHabitReminders(for: id)
        guard !habit.isArchived, let hour = habit.reminderHour, let minute = habit.reminderMinute else { return }
        guard await requestAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = habit.name
        content.body = habit.kind == .binary
            ? "Es hora de tu hábito."
            : "Meta de hoy: \(habit.goalDescription)."
        content.sound = .default

        var requests: [UNNotificationRequest] = []
        if habit.frequency == .specificDays {
            for weekday in habit.weekdays {
                var components = DateComponents()
                components.weekday = weekday
                components.hour = hour
                components.minute = minute
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                requests.append(UNNotificationRequest(identifier: "habit-\(id.uuidString)-wd\(weekday)",
                                                      content: content, trigger: trigger))
            }
        } else {
            var components = DateComponents()
            components.hour = hour
            components.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            requests.append(UNNotificationRequest(identifier: "habit-\(id.uuidString)-daily",
                                                  content: content, trigger: trigger))
        }

        for request in requests {
            try? await center.add(request)
        }
    }

    /// Vuelve a programar todo (por ejemplo, después de importar un respaldo).
    static func rescheduleAll(context: ModelContext) async {
        center.removeAllPendingNotificationRequests()
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        for habit in habits {
            await scheduleHabitReminder(for: habit)
        }
    }
}
