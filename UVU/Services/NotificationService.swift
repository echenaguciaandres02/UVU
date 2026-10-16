import Foundation
import SwiftData
import UIKit
import UserNotifications

/// Programa las notificaciones locales de la app.
@MainActor
enum NotificationService {
    private static var center: UNUserNotificationCenter { .current() }

    /// Durante las pruebas automáticas no se piden permisos ni se programan avisos: el cuadro
    /// "¿Permitir notificaciones?" bloquearía las pruebas de interfaz.
    static var isDisabledForTesting: Bool {
        let process = ProcessInfo.processInfo
        return process.environment["XCTestConfigurationFilePath"] != nil
            || process.arguments.contains("-uvu-no-notifications")
            || process.arguments.contains("-uvu-demo-data")
    }

    /// Pide permiso la primera vez. Devuelve si se pueden enviar notificaciones.
    @discardableResult
    static func requestAuthorization() async -> Bool {
        if isDisabledForTesting { return false }
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

    // MARK: - Tareas

    static let taskCategory = "TASK_REMINDER"
    static let completeAction = "TASK_COMPLETE"
    static let snoozeAction = "TASK_SNOOZE"
    static let taskIDKey = "taskID"

    /// Categoría con los botones "Completar" y "Posponer 1 hora" (se registra al abrir la app).
    static func registerCategories() {
        let complete = UNNotificationAction(identifier: completeAction, title: "Completar", options: [])
        let snooze = UNNotificationAction(identifier: snoozeAction, title: "Posponer 1 hora", options: [])
        let category = UNNotificationCategory(identifier: taskCategory, actions: [complete, snooze],
                                              intentIdentifiers: [], options: [])
        center.setNotificationCategories([category])
    }

    private static func taskIdentifier(_ id: UUID) -> String { "task-\(id.uuidString)" }
    private static func snoozeIdentifier(_ id: UUID) -> String { "task-\(id.uuidString)-snooze" }

    static func removeTaskReminders(for id: UUID) {
        let identifiers = [taskIdentifier(id), snoozeIdentifier(id)]
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
        center.removeDeliveredNotifications(withIdentifiers: identifiers)
    }

    private static func content(for task: TaskItem) -> UNMutableNotificationContent {
        let content = UNMutableNotificationContent()
        content.title = task.title
        var parts: [String] = []
        if let due = task.dueDate {
            parts.append("Vence " + TaskSchedule.dueDescription(due: due, hasTime: task.hasTime).lowercased())
        }
        if let list = task.list?.name { parts.append(list) }
        content.body = parts.joined(separator: " · ")
        content.sound = .default
        content.categoryIdentifier = taskCategory
        content.threadIdentifier = "tasks"
        content.userInfo = [taskIDKey: task.id.uuidString]
        return content
    }

    /// Reemplaza el aviso de la tarea según su fecha, hora y anticipación actuales.
    static func scheduleTaskReminder(for task: TaskItem, now: Date = .now) async {
        removeTaskReminders(for: task.id)
        guard !task.isCompleted,
              let fireDate = TaskSchedule.reminderDate(due: task.dueDate, hasTime: task.hasTime,
                                                       reminderEnabled: task.reminderEnabled,
                                                       offsetMinutes: task.reminderOffsetMinutes),
              fireDate > now
        else { return }
        guard await requestAuthorization() else { return }

        let components = AppCalendar.calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        let request = UNNotificationRequest(identifier: taskIdentifier(task.id), content: content(for: task),
                                            trigger: trigger)
        try? await center.add(request)
    }

    /// "Posponer 1 hora": vuelve a avisar en una hora. La fecha límite no cambia.
    static func snoozeTaskReminder(for task: TaskItem) async {
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 3600, repeats: false)
        let request = UNNotificationRequest(identifier: snoozeIdentifier(task.id), content: content(for: task),
                                            trigger: trigger)
        try? await center.add(request)
    }

    /// Vuelve a programar todo (al importar un respaldo o cambiar la hora por defecto).
    static func rescheduleAll(context: ModelContext) async {
        center.removeAllPendingNotificationRequests()
        let habits = (try? context.fetch(FetchDescriptor<Habit>())) ?? []
        for habit in habits {
            await scheduleHabitReminders(for: habit)
        }
        await rescheduleTasks(context: context)
    }

    static func rescheduleTasks(context: ModelContext) async {
        let pending = (try? context.fetch(FetchDescriptor<TaskItem>(predicate: #Predicate { $0.isCompleted == false }))) ?? []
        for task in pending where task.dueDate != nil {
            await scheduleTaskReminder(for: task)
        }
    }

    /// Responde a los botones de la notificación de una tarea.
    static func handle(actionIdentifier: String, userInfo: [AnyHashable: Any]) async {
        guard let raw = userInfo[taskIDKey] as? String, let id = UUID(uuidString: raw) else { return }
        let context = AppContainer.shared.mainContext
        guard let task = TaskActions.task(id: id, in: context) else { return }
        switch actionIdentifier {
        case completeAction:
            TaskActions.complete(task, in: context)
        case snoozeAction:
            await snoozeTaskReminder(for: task)
        default:
            break
        }
    }
}

/// Muestra las notificaciones con la app abierta y atiende sus botones.
final class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .list, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let action = response.actionIdentifier
        let userInfo = response.notification.request.content.userInfo
        Task { @MainActor in
            await NotificationService.handle(actionIdentifier: action, userInfo: userInfo)
            completionHandler()
        }
    }
}

final class AppDelegate: NSObject, UIApplicationDelegate {
    private let notificationDelegate = NotificationDelegate()

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = notificationDelegate
        NotificationService.registerCategories()
        return true
    }
}
