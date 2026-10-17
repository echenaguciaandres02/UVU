import ActivityKit
import Foundation
import Observation
import UserNotifications

/// Temporizador de descanso entre series.
/// - Muestra una Live Activity con la cuenta atrás en la pantalla de bloqueo y la Dynamic Island.
/// - Programa una notificación para el final del descanso (avisa aunque el teléfono esté bloqueado).
@MainActor
@Observable
final class RestTimer {
    static let shared = RestTimer()
    private static let notificationID = "rest-timer"

    private(set) var endDate: Date?
    private(set) var startDate: Date?
    private(set) var duration: TimeInterval = 90
    private(set) var exerciseName = ""
    private(set) var nextSet = ""
    private var workoutName = ""
    private var activity: Activity<RestActivityAttributes>?

    var isRunning: Bool { endDate != nil }

    func remaining(at now: Date = .now) -> TimeInterval {
        guard let endDate else { return 0 }
        return max(0, endDate.timeIntervalSince(now))
    }

    func start(seconds: Int, exerciseName: String, nextSet: String = "", workoutName: String = "", now: Date = .now) {
        duration = TimeInterval(max(seconds, 5))
        startDate = now
        endDate = now.addingTimeInterval(duration)
        self.exerciseName = exerciseName
        self.nextSet = nextSet
        self.workoutName = workoutName
        scheduleNotification()
        startOrUpdateActivity()
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
        scheduleNotification()
        startOrUpdateActivity()
    }

    func stop() {
        endDate = nil
        startDate = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        endActivity()
    }

    /// Llamado por la pantalla cuando llega a cero estando abierta.
    func finishIfElapsed(now: Date = .now) -> Bool {
        guard let endDate, endDate <= now else { return false }
        self.endDate = nil
        startDate = nil
        endActivity()
        return true
    }

    /// Al volver a la app: si el descanso ya terminó mientras estaba bloqueada, cierra la Live Activity.
    func refresh(now: Date = .now) {
        if let endDate, endDate <= now {
            _ = finishIfElapsed(now: now)
        } else if endDate == nil {
            endActivity()
        }
    }

    // MARK: - Notificación

    private func scheduleNotification() {
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

    // MARK: - Live Activity

    private var contentState: RestActivityAttributes.ContentState? {
        guard let startDate, let endDate else { return nil }
        return RestActivityAttributes.ContentState(startDate: startDate, endDate: endDate,
                                                   exerciseName: exerciseName, nextSet: nextSet)
    }

    private func startOrUpdateActivity() {
        guard let state = contentState else { return }
        // `staleDate`: al terminar, el sistema la marca como vencida aunque la app esté dormida.
        let content = ActivityContent(state: state, staleDate: state.endDate)
        if let activity, activity.activityState == .active {
            Task { await activity.update(content) }
            return
        }
        // Con Sideloadly y Apple ID gratuito la extensión no queda bien firmada: iOS acepta la
        // actividad pero no la dibuja. Con otra forma de instalar (AltStore) sí se vería.
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        endStaleActivities()
        let attributes = RestActivityAttributes(workoutName: workoutName.isEmpty ? "Entreno" : workoutName)
        activity = try? Activity.request(attributes: attributes, content: content, pushType: nil)
    }

    private func endActivity() {
        guard let current = activity else {
            endStaleActivities()
            return
        }
        activity = nil
        Task { await current.end(nil, dismissalPolicy: .immediate) }
    }

    /// Cierra actividades que hayan quedado de un descanso anterior (por ejemplo, si la app se cerró).
    private func endStaleActivities() {
        for leftover in Activity<RestActivityAttributes>.activities where leftover.id != activity?.id {
            Task { await leftover.end(nil, dismissalPolicy: .immediate) }
        }
    }
}
