import Foundation
import Observation
import UserNotifications

/// Temporizador de descanso entre series. Al empezar programa una notificación local para el
/// final del descanso, así avisa aunque el teléfono esté bloqueado o la app en segundo plano.
@MainActor
@Observable
final class RestTimer {
    static let shared = RestTimer()
    private static let notificationID = "rest-timer"

    private(set) var endDate: Date?
    private(set) var duration: TimeInterval = 90
    private(set) var exerciseName = ""

    var isRunning: Bool { endDate != nil }

    func remaining(at now: Date = .now) -> TimeInterval {
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSince(now))
    }

    func start(seconds: Int, exerciseName: String, now: Date = .now) {
        duration = TimeInterval(max(seconds, 5))
        endDate = now.addingTimeInterval(duration)
        self.exerciseName = exerciseName
        schedule()
    }

    /// +15 / −15 segundos.
    func adjust(by seconds: Int, now: Date = .now) {
        guard let endDate else { return }
        let newEnd = endDate.addingTimeInterval(TimeInterval(seconds))
        guard newEnd > now.addingTimeInterval(3) else {
            stop()
            return
        }
        self.endDate = newEnd
        duration = max(duration + TimeInterval(seconds), 5)
        schedule()
    }

    func stop() {
        endDate = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    /// Llamado por la pantalla cuando llega a cero estando abierta.
    func finishIfElapsed(now: Date = .now) -> Bool {
        guard let endDate, endDate <= now else { return false }
        self.endDate = nil
        return true
    }

    private func schedule() {
        guard let endDate else { return }
        let name = exerciseName
        let interval = max(1, endDate.timeIntervalSinceNow)
        Task {
            guard await NotificationService.requestAuthorization() else { return }
            let content = UNMutableNotificationContent()
            content.title = "Descanso terminado"
            content.body = name.isEmpty ? "A la siguiente serie." : "Siguiente serie: \(name)."
            content.sound = .default
            content.interruptionLevel = .timeSensitive
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            let request = UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger)
            try? await UNUserNotificationCenter.current().add(request)
        }
    }
}
