import XCTest
import SwiftData
@testable import UVU

@MainActor
final class BackupServiceTests: XCTestCase {

    func testRoundTripKeepsAllData() throws {
        // Los contenedores se guardan en variables para que sigan vivos durante la prueba.
        let sourceContainer = DataStore.makeContainer(inMemory: true)
        let source = sourceContainer.mainContext
        SeedData.seed(context: source)
        try addSampleData(to: source)

        let data = try BackupService.encode(BackupService.makeBackup(context: source))
        let original = try BackupService.decode(data)

        let targetContainer = DataStore.makeContainer(inMemory: true)
        let target = targetContainer.mainContext
        try BackupService.restore(original, into: target)

        var restored = try BackupService.decode(BackupService.encode(BackupService.makeBackup(context: target)))
        restored.exportedAt = original.exportedAt

        XCTAssertEqual(restored, original)
        XCTAssertEqual(original.habits.count, 8)
        XCTAssertEqual(original.journalEntries.first?.tags, ["gym", "tesis"])
        XCTAssertEqual(original.sessions.first?.exercises.first?.sets.count, 2)
    }

    func testRestoreReplacesExistingData() throws {
        let container = DataStore.makeContainer(inMemory: true)
        let context = container.mainContext
        SeedData.seed(context: context)

        let empty = BackupFile(version: 1, exportedAt: .now, habits: [], taskLists: [],
                               journalEntries: [], exercises: [], routines: [], sessions: [])
        try BackupService.restore(empty, into: context)

        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Habit>()), 0)
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<Exercise>()), 0)
    }

    func testRejectsNewerVersion() throws {
        let future = BackupFile(version: BackupFile.currentVersion + 1, exportedAt: .now, habits: [], taskLists: [],
                                journalEntries: [], exercises: [], routines: [], sessions: [])
        let data = try BackupService.encode(future)
        XCTAssertThrowsError(try BackupService.decode(data))
    }

    func testWeightConversion() {
        XCTAssertEqual(WeightUnit.kg.convert(100, to: .lb), 220.462, accuracy: 0.001)
        XCTAssertEqual(WeightUnit.lb.convert(45, to: .kg), 20.412, accuracy: 0.001)
        XCTAssertEqual(WeightUnit.kg.convert(60, to: .kg), 60)
    }

    private func addSampleData(to context: ModelContext) throws {
        let habit = try XCTUnwrap(context.fetch(FetchDescriptor<Habit>()).first)
        let entry = HabitEntry(date: .now, value: 1)
        context.insert(entry)
        entry.habit = habit

        let list = try XCTUnwrap(context.fetch(FetchDescriptor<TaskList>()).first)
        let task = TaskItem(title: "Entregar capítulo 2", dueDate: .now, hasTime: true)
        task.priority = .high
        task.recurrence = .weekly
        context.insert(task)
        task.list = list
        let subtask = Subtask(title: "Revisar bibliografía", order: 0)
        context.insert(subtask)
        subtask.task = task

        let journal = JournalEntry(date: .now, text: "Buen día.", mood: 4)
        context.insert(journal)
        let tagA = JournalTag(name: "tesis")
        let tagB = JournalTag(name: "gym")
        context.insert(tagA)
        context.insert(tagB)
        journal.tags = [tagA, tagB]
        let answer = PromptAnswer(question: "¿Qué salió bien hoy?", answer: "Entrené.", order: 0)
        context.insert(answer)
        answer.entry = journal

        let bench = try XCTUnwrap(context.fetch(FetchDescriptor<Exercise>()).first { $0.name == "Press de banca" })
        let routine = Routine(name: "Push", weekdays: [2, 5])
        context.insert(routine)
        let routineItem = RoutineExercise(order: 0, targetSets: 4, targetReps: 8)
        context.insert(routineItem)
        routineItem.routine = routine
        routineItem.exercise = bench

        let session = WorkoutSession(startedAt: .now)
        session.endedAt = .now
        context.insert(session)
        session.routine = routine
        let sessionExercise = SessionExercise(order: 0)
        context.insert(sessionExercise)
        sessionExercise.session = session
        sessionExercise.exercise = bench
        for (index, (weight, unit)) in [(60.0, WeightUnit.kg), (135.0, WeightUnit.lb)].enumerated() {
            let set = WorkoutSet(order: index, weight: weight, unit: unit, reps: 8)
            set.rpe = 8
            set.isCompleted = true
            context.insert(set)
            set.sessionExercise = sessionExercise
        }

        try context.save()
    }
}
