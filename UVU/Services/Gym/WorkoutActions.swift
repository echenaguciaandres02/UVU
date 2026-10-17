import Foundation
import SwiftData

/// Sesiones de entrenamiento: empezar, registrar series, terminar y consultar el historial.
@MainActor
enum WorkoutActions {

    /// Sesión sin terminar, si hay una.
    static func activeSession(in context: ModelContext) -> WorkoutSession? {
        var descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.endedAt == nil },
                                                         sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Empieza una sesión (vacía o desde una rutina). Las series vienen precargadas con lo que
    /// hiciste la última vez en cada ejercicio; si nunca lo hiciste, con las repeticiones objetivo.
    @discardableResult
    static func start(routine: Routine?, unit: WeightUnit, in context: ModelContext, now: Date = .now) -> WorkoutSession {
        if let active = activeSession(in: context) { return active }
        let session = WorkoutSession(startedAt: now)
        context.insert(session)
        session.routine = routine
        for item in routine?.sortedItems ?? [] {
            guard let exercise = item.exercise else { continue }
            addExercise(exercise, to: session, targetSets: item.targetSets, targetReps: item.targetReps,
                        restSeconds: item.restSeconds, unit: unit, in: context)
        }
        try? context.save()
        return session
    }

    @discardableResult
    static func addExercise(_ exercise: Exercise, to session: WorkoutSession, targetSets: Int = 3, targetReps: Int = 10,
                            restSeconds: Int = 90, unit: WeightUnit, in context: ModelContext) -> SessionExercise {
        let order = (session.exercises?.map(\.order).max() ?? -1) + 1
        let sessionExercise = SessionExercise(order: order)
        sessionExercise.restSeconds = restSeconds
        context.insert(sessionExercise)
        sessionExercise.session = session
        sessionExercise.exercise = exercise

        let previous = lastPerformance(of: exercise, before: session, in: context)
        let count = max(targetSets, previous.count, 1)
        for index in 0..<count {
            let template = previous.indices.contains(index) ? previous[index] : previous.last
            let set = WorkoutSet(order: index,
                                 weight: template?.weight ?? 0,
                                 unit: template?.unit ?? unit,
                                 reps: template?.reps ?? targetReps)
            context.insert(set)
            set.sessionExercise = sessionExercise
        }
        try? context.save()
        return sessionExercise
    }

    /// Agrega una serie copiando el peso y las repeticiones de la anterior.
    @discardableResult
    static func addSet(to sessionExercise: SessionExercise, unit: WeightUnit, in context: ModelContext) -> WorkoutSet {
        let last = sessionExercise.sortedSets.last
        let set = WorkoutSet(order: (last?.order ?? -1) + 1, weight: last?.weight ?? 0,
                             unit: last?.unit ?? unit, reps: last?.reps ?? 10)
        set.rpe = last?.rpe
        context.insert(set)
        set.sessionExercise = sessionExercise
        try? context.save()
        return set
    }

    static func toggle(_ set: WorkoutSet, in context: ModelContext, now: Date = .now) {
        set.isCompleted.toggle()
        set.completedAt = set.isCompleted ? now : nil
        try? context.save()
    }

    /// Termina la sesión: descarta las series no marcadas y los ejercicios sin series, y marca
    /// el hábito "Ejercicio" del día. Devuelve `false` si no había nada hecho (la sesión se borra).
    @discardableResult
    static func finish(_ session: WorkoutSession, in context: ModelContext, now: Date = .now) -> Bool {
        for exercise in session.exercises ?? [] {
            for set in exercise.sets ?? [] where !set.isCompleted || set.reps <= 0 {
                context.delete(set)
            }
        }
        try? context.save()
        for exercise in session.exercises ?? [] where (exercise.sets ?? []).isEmpty {
            context.delete(exercise)
        }
        try? context.save()

        guard !(session.exercises ?? []).isEmpty else {
            context.delete(session)
            try? context.save()
            return false
        }
        session.endedAt = now
        try? context.save()
        HabitActions.complete(systemRole: HabitSystemRole.exercise, on: session.startedAt, in: context)
        return true
    }

    static func discard(_ session: WorkoutSession, in context: ModelContext) {
        context.delete(session)
        try? context.save()
    }

    // MARK: - Historial

    static func finishedSessions(in context: ModelContext) -> [WorkoutSession] {
        let descriptor = FetchDescriptor<WorkoutSession>(predicate: #Predicate { $0.endedAt != nil },
                                                         sortBy: [SortDescriptor(\.startedAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    /// Series completadas de la última sesión terminada (anterior a `session`) con ese ejercicio.
    static func lastPerformance(of exercise: Exercise, before session: WorkoutSession? = nil,
                                in context: ModelContext) -> [WorkoutSet] {
        let items = (exercise.sessionItems ?? []).filter { item in
            guard let owner = item.session, let ended = owner.endedAt else { return false }
            if let session, owner.id == session.id { return false }
            if let session { return ended <= session.startedAt || owner.startedAt < session.startedAt }
            return true
        }
        let latest = items.max { ($0.session?.startedAt ?? .distantPast) < ($1.session?.startedAt ?? .distantPast) }
        return latest?.completedSets ?? []
    }

    /// "60 kg × 8 · 60 × 8 · 62,5 × 6"
    static func describe(_ sets: [WorkoutSet]) -> String? {
        guard let first = sets.first else { return nil }
        var parts = ["\(GymMath.format(first.weight, unit: first.unit)) × \(first.reps)"]
        for set in sets.dropFirst() {
            let weight = set.unit == first.unit ? NumberText.format(set.weight) : GymMath.format(set.weight, unit: set.unit)
            parts.append("\(weight) × \(set.reps)")
        }
        return parts.joined(separator: " · ")
    }

    /// Estadísticas por sesión de un ejercicio (sesiones terminadas, de la más antigua a la más reciente).
    static func stats(for exercise: Exercise, unit: WeightUnit) -> [ExerciseSessionStat] {
        (exercise.sessionItems ?? []).compactMap { item -> ExerciseSessionStat? in
            guard let session = item.session, session.endedAt != nil else { return nil }
            let samples = item.completedSets.map { SetSample(weight: $0.weight, unit: $0.unit, reps: $0.reps) }
            return ExerciseStatsCalculator.stat(sessionID: session.id, date: session.startedAt, sets: samples, unit: unit)
        }
        .sorted { $0.date < $1.date }
    }

    /// Volumen total de la sesión (series completadas) en la unidad pedida.
    static func volume(of session: WorkoutSession, unit: WeightUnit) -> Double {
        session.sortedExercises.flatMap(\.completedSets).reduce(0) { $0 + $1.weight(in: unit) * Double($1.reps) }
    }

    /// Ejercicios de la sesión que batieron un récord.
    static func recordExercises(in session: WorkoutSession, unit: WeightUnit) -> [String] {
        session.sortedExercises.compactMap { item in
            guard let exercise = item.exercise else { return nil }
            let all = stats(for: exercise, unit: unit)
            guard let current = all.first(where: { $0.sessionID == session.id }) else { return nil }
            let result = ExerciseStatsCalculator.isRecord(current, previous: all)
            return (result.weight || result.oneRepMax) ? exercise.name : nil
        }
    }
}
