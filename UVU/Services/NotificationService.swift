import Foundation
import SwiftData
import UIKit
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

    private static func habitPrefix(_ id: UUID) -> String {
        "habit-\(id.uuidString)-"
    }

    static func removeHabitReminders(for id: UUID) async {
        let prefix = habitPrefix(id)
        let pending = await center.pendingNotificationRequests()
        let identifiers = pending.map(\.identifier).filter { $0.hasPrefix(prefix) }
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    /// Reemplaza los recordatorios del hábito según sus horas y frecuencia actuales.
    static func scheduleHabitReminders(for habit: Habit) async {
        let id = habit.id
        let times = Array(Set(habit.reminderMinutes)).sorted()
        await removeHabitReminders(for: id)
        guard !habit.isArchived, !times.isEmpty else { return }
        guard await requestAuthorization() else { return }

        let content = UNMutableNotificationContent()
        content.title = habit.name
        content.body = habit.kind == .binary
            ? "Es hora de tu hábito."
            : "Meta de hoy: \(habit.goalDescription)."
        content.sound = .default
        content.threadIdentifier = "habit-\(id.uuidString)"

        let weekdays: [Int?] = habit.frequency == .specificDays ? habit.weekdays.map { Optional($0) } : [nil]
        for minutes in times {
            for weekday in weekdays {
                var components = DateComponents()
                components.hour = minutes / 60
                components.minute = minutes % 60
                components.weekday = weekday
                let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
                let suffix = weekday.map { "wd\($0)" } ?? "daily"
                let request = UNNotificationRequest(identifier: "\(habitPrefix(id))\(minutes)-\(suffix)",
                                                    content: content, trigger: trigger)
                try? await center.add(request)
            }
        }
    }

    /// Cuántas notificaciones pendientes usaría el hábito (iOS permite 64 en total).
    static func notificationCount(times: Int, frequency: HabitFrequency, weekdays: Int) -> Int {
        times * (frequency == .specificDays ? weekdays : 1)
    }

    /// Vuelve a programar todo (por ejemplo, después de importar un respaldo).
    static func rescheduleAll(context: ModelContext) async {
        center.removeAllPendingNotificationRequests()
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        for habit in habits {
            await scheduleHabitReminders(for: habit)
        }
    }
}

/// Muestra las notificaciones también cuando la app está abierta.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    private let notificationDelegate = NotificationDelegate()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        return true
    }
}
