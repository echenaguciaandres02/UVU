import Foundation
import SwiftData

enum BackupError: LocalizedError {
    case unsupportedVersion(Int)
    case notUVUBackup

    var errorDescription: String? {
        switch self {
        case .unsupportedVersion(let version):
            return "Este respaldo es de una versión más nueva de UVU (formato \(version)). Actualiza la app para importarlo."
        case .notUVUBackup:
            return "El archivo no es un respaldo de UVU."
        }
    }
}

/// Exporta e importa todos los datos de la app como JSON.
@MainActor
enum BackupService {

    // MARK: - Exportar

    static func makeBackup(context: ModelContext) throws -> BackupFile {
        let habits = try context.fetch(FetchDescriptor<Habit>())
            .sorted { ($0.sortOrder, $0.id.uuidString) < ($1.sortOrder, $1.id.uuidString) }
        let lists = try context.fetch(FetchDescriptor<TaskList>())
            .sorted { ($0.sortOrder, $0.id.uuidString) < ($1.sortOrder, $1.id.uuidString) }
        let journal = try context.fetch(FetchDescriptor<JournalEntry>())
            .sorted { ($0.date, $0.id.uuidString) < ($1.date, $1.id.uuidString) }
        let exercises = try context.fetch(FetchDescriptor<Exercise>())
            .sorted { ($0.name, $0.id.uuidString) < ($1.name, $1.id.uuidString) }
        let routines = try context.fetch(FetchDescriptor<Routine>())
            .sorted { ($0.sortOrder, $0.id.uuidString) < ($1.sortOrder, $1.id.uuidString) }
        let sessions = try context.fetch(FetchDescriptor<WorkoutSession>())
            .sorted { ($0.startedAt, $0.id.uuidString) < ($1.startedAt, $1.id.uuidString) }

        return BackupFile(
            version: BackupFile.currentVersion,
            exportedAt: Date(),
            habits: habits.map(dto),
            taskLists: lists.map(dto),
            journalEntries: journal.map(dto),
            exercises: exercises.map(dto),
            routines: routines.map(dto),
            sessions: sessions.map(dto)
        )
    }

    static func encode(_ backup: BackupFile) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(backup)
    }

    /// Escribe el respaldo en un archivo temporal listo para la hoja de Compartir.
    static func exportFile(context: ModelContext) throws -> URL {
        let data = try encode(makeBackup(context: context))
        let day = Date.now.formatted(.iso8601.year().month().day())
        let url = FileManager.default.temporaryDirectory.appending(path: "UVU-respaldo-\(day).json")
        try data.write(to: url, options: .atomic)
        return url
    }

    // MARK: - Importar

    static func decode(_ data: Data) throws -> BackupFile {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(BackupFile.self, from: data)
        guard backup.app == "UVU" else { throw BackupError.notUVUBackup }
        guard backup.version <= BackupFile.currentVersion else {
            throw BackupError.unsupportedVersion(backup.version)
        }
        return backup
    }

    /// Borra todos los datos actuales y los reemplaza por los del respaldo.
    static func restore(_ backup: BackupFile, into context: ModelContext) throws {
        try deleteAllData(in: context)

        var exercisesByID: [UUID: Exercise] = [:]
        for item in backup.exercises {
            let exercise = Exercise(name: item.name, muscle: MuscleGroup(rawValue: item.muscleGroup) ?? .other,
                                    equipment: item.equipment, isCustom: item.isCustom)
            exercise.id = item.id
            exercise.notes = item.notes
            exercise.createdAt = item.createdAt
            context.insert(exercise)
            exercisesByID[item.id] = exercise
        }

        for item in backup.habits {
            let habit = Habit(name: item.name, symbol: item.symbol, colorHex: item.colorHex,
                              target: item.target, unit: item.unit, sortOrder: item.sortOrder,
                              systemRole: item.systemRole)
            habit.id = item.id
            habit.kindRaw = item.kind
            habit.frequencyRaw = item.frequency
            habit.weekdays = item.weekdays
            habit.timesPerWeek = item.timesPerWeek
            habit.reminderHour = item.reminderHour
            habit.reminderMinute = item.reminderMinute
            habit.isArchived = item.isArchived
            habit.createdAt = item.createdAt
            context.insert(habit)
            for entryItem in item.entries {
                let entry = HabitEntry(date: entryItem.date, value: entryItem.value)
                context.insert(entry)
                entry.habit = habit
            }
        }

        for item in backup.taskLists {
            let list = TaskList(name: item.name, symbol: item.symbol, colorHex: item.colorHex, sortOrder: item.sortOrder)
            list.id = item.id
            list.createdAt = item.createdAt
            context.insert(list)
            for taskItem in item.tasks {
                let task = TaskItem(title: taskItem.title, notes: taskItem.notes,
                                    dueDate: taskItem.dueDate, hasTime: taskItem.hasTime)
                task.id = taskItem.id
                task.priorityRaw = taskItem.priority
                task.recurrenceRaw = taskItem.recurrence
                task.isCompleted = taskItem.isCompleted
                task.completedAt = taskItem.completedAt
                task.createdAt = taskItem.createdAt
                context.insert(task)
                task.list = list
                for subItem in taskItem.subtasks {
                    let subtask = Subtask(title: subItem.title, order: subItem.order)
                    subtask.isDone = subItem.isDone
                    context.insert(subtask)
                    subtask.task = task
                }
            }
        }

        var tagsByName: [String: JournalTag] = [:]
        for item in backup.journalEntries {
            let entry = JournalEntry(date: item.date, text: item.text, mood: item.mood)
            entry.id = item.id
            entry.createdAt = item.createdAt
            entry.updatedAt = item.updatedAt
            context.insert(entry)
            for answerItem in item.answers {
                let answer = PromptAnswer(question: answerItem.question, answer: answerItem.answer, order: answerItem.order)
                context.insert(answer)
                answer.entry = entry
            }
            var tags: [JournalTag] = []
            for name in item.tags {
                let key = name.lowercased()
                if let existing = tagsByName[key] {
                    tags.append(existing)
                } else {
                    let tag = JournalTag(name: name)
                    context.insert(tag)
                    tagsByName[key] = tag
                    tags.append(tag)
                }
            }
            entry.tags = tags
        }

        var routinesByID: [UUID: Routine] = [:]
        for item in backup.routines {
            let routine = Routine(name: item.name, weekdays: item.weekdays, colorHex: item.colorHex, sortOrder: item.sortOrder)
            routine.id = item.id
            routine.createdAt = item.createdAt
            context.insert(routine)
            routinesByID[item.id] = routine
            for routineItem in item.items {
                let entry = RoutineExercise(order: routineItem.order, targetSets: routineItem.targetSets,
                                            targetReps: routineItem.targetReps)
                context.insert(entry)
                entry.routine = routine
                entry.exercise = routineItem.exerciseID.flatMap { exercisesByID[$0] }
            }
        }

        for item in backup.sessions {
            let session = WorkoutSession(startedAt: item.startedAt)
            session.id = item.id
            session.endedAt = item.endedAt
            session.notes = item.notes
            context.insert(session)
            session.routine = item.routineID.flatMap { routinesByID[$0] }
            for exerciseItem in item.exercises {
                let sessionExercise = SessionExercise(order: exerciseItem.order)
                context.insert(sessionExercise)
                sessionExercise.session = session
                sessionExercise.exercise = exerciseItem.exerciseID.flatMap { exercisesByID[$0] }
                for setItem in exerciseItem.sets {
                    let set = WorkoutSet(order: setItem.order, weight: setItem.weight,
                                         unit: WeightUnit(rawValue: setItem.unit) ?? .kg, reps: setItem.reps)
                    set.rpe = setItem.rpe
                    set.isCompleted = setItem.isCompleted
                    set.completedAt = setItem.completedAt
                    context.insert(set)
                    set.sessionExercise = sessionExercise
                }
            }
        }

        try context.save()
    }

    /// Borra todo, de los hijos hacia los padres.
    static func deleteAllData(in context: ModelContext) throws {
        try deleteAll(WorkoutSet.self, in: context)
        try deleteAll(SessionExercise.self, in: context)
        try deleteAll(WorkoutSession.self, in: context)
        try deleteAll(RoutineExercise.self, in: context)
        try deleteAll(Routine.self, in: context)
        try deleteAll(Exercise.self, in: context)
        try deleteAll(PromptAnswer.self, in: context)
        try deleteAll(JournalEntry.self, in: context)
        try deleteAll(JournalTag.self, in: context)
        try deleteAll(Subtask.self, in: context)
        try deleteAll(TaskItem.self, in: context)
        try deleteAll(TaskList.self, in: context)
        try deleteAll(HabitEntry.self, in: context)
        try deleteAll(Habit.self, in: context)
        try context.save()
    }

    private static func deleteAll<T: PersistentModel>(_ type: T.Type, in context: ModelContext) throws {
        for object in try context.fetch(FetchDescriptor<T>()) {
            context.delete(object)
        }
    }

    // MARK: - Modelo → DTO

    private static func dto(_ habit: Habit) -> HabitDTO {
        HabitDTO(
            id: habit.id, name: habit.name, symbol: habit.symbol, colorHex: habit.colorHex,
            kind: habit.kindRaw, target: habit.target, unit: habit.unit,
            frequency: habit.frequencyRaw, weekdays: habit.weekdays.sorted(), timesPerWeek: habit.timesPerWeek,
            reminderHour: habit.reminderHour, reminderMinute: habit.reminderMinute,
            systemRole: habit.systemRole, sortOrder: habit.sortOrder, isArchived: habit.isArchived,
            createdAt: habit.createdAt,
            entries: (habit.entries ?? [])
                .sorted { $0.date < $1.date }
                .map { HabitEntryDTO(date: $0.date, value: $0.value) }
        )
    }

    private static func dto(_ list: TaskList) -> TaskListDTO {
        TaskListDTO(
            id: list.id, name: list.name, symbol: list.symbol, colorHex: list.colorHex,
            sortOrder: list.sortOrder, createdAt: list.createdAt,
            tasks: (list.tasks ?? [])
                .sorted { ($0.createdAt, $0.id.uuidString) < ($1.createdAt, $1.id.uuidString) }
                .map(dto)
        )
    }

    private static func dto(_ task: TaskItem) -> TaskItemDTO {
        TaskItemDTO(
            id: task.id, title: task.title, notes: task.notes, dueDate: task.dueDate, hasTime: task.hasTime,
            priority: task.priorityRaw, recurrence: task.recurrenceRaw, isCompleted: task.isCompleted,
            completedAt: task.completedAt, createdAt: task.createdAt,
            subtasks: (task.subtasks ?? [])
                .sorted { ($0.order, $0.title) < ($1.order, $1.title) }
                .map { SubtaskDTO(title: $0.title, isDone: $0.isDone, order: $0.order) }
        )
    }

    private static func dto(_ entry: JournalEntry) -> JournalEntryDTO {
        JournalEntryDTO(
            id: entry.id, date: entry.date, text: entry.text, mood: entry.mood,
            createdAt: entry.createdAt, updatedAt: entry.updatedAt,
            tags: (entry.tags ?? []).map(\.name).sorted(),
            answers: (entry.answers ?? [])
                .sorted { ($0.order, $0.question) < ($1.order, $1.question) }
                .map { PromptAnswerDTO(question: $0.question, answer: $0.answer, order: $0.order) }
        )
    }

    private static func dto(_ exercise: Exercise) -> ExerciseDTO {
        ExerciseDTO(
            id: exercise.id, name: exercise.name, muscleGroup: exercise.muscleRaw, equipment: exercise.equipment,
            isCustom: exercise.isCustom, notes: exercise.notes, createdAt: exercise.createdAt
        )
    }

    private static func dto(_ routine: Routine) -> RoutineDTO {
        RoutineDTO(
            id: routine.id, name: routine.name, weekdays: routine.weekdays.sorted(), colorHex: routine.colorHex,
            sortOrder: routine.sortOrder, createdAt: routine.createdAt,
            items: (routine.items ?? [])
                .sorted { $0.order < $1.order }
                .map {
                    RoutineExerciseDTO(order: $0.order, targetSets: $0.targetSets,
                                       targetReps: $0.targetReps, exerciseID: $0.exercise?.id)
                }
        )
    }

    private static func dto(_ session: WorkoutSession) -> WorkoutSessionDTO {
        WorkoutSessionDTO(
            id: session.id, startedAt: session.startedAt, endedAt: session.endedAt, notes: session.notes,
            routineID: session.routine?.id,
            exercises: (session.exercises ?? [])
                .sorted { $0.order < $1.order }
                .map { item in
                    SessionExerciseDTO(
                        order: item.order,
                        exerciseID: item.exercise?.id,
                        sets: (item.sets ?? [])
                            .sorted { $0.order < $1.order }
                            .map {
                                WorkoutSetDTO(order: $0.order, weight: $0.weight, unit: $0.unitRaw, reps: $0.reps,
                                              rpe: $0.rpe, isCompleted: $0.isCompleted, completedAt: $0.completedAt)
                            }
                    )
                }
        )
    }
}
