import XCTest
import SwiftData
@testable import UVU

final class GymMathTests: XCTestCase {

    func testEpleyOneRepMax() {
        XCTAssertEqual(GymMath.estimatedOneRepMax(weight: 100, reps: 1), 100)
        XCTAssertEqual(GymMath.estimatedOneRepMax(weight: 100, reps: 10), 133.333, accuracy: 0.01)
        XCTAssertEqual(GymMath.estimatedOneRepMax(weight: 0, reps: 10), 0)
        XCTAssertEqual(GymMath.estimatedOneRepMax(weight: 80, reps: 0), 0)
    }

    func testStatsMixUnitsAndDetectRecords() throws {
        let day1 = Date(timeIntervalSince1970: 1_800_000_000)
        let day2 = day1.addingTimeInterval(7 * 86_400)
        let day3 = day2.addingTimeInterval(7 * 86_400)

        // 60 kg × 8 y 135 lb (61,2 kg) × 5 → peso máx 61,2; 1RM máx = 60 × (1 + 8/30) = 76.
        let first = try XCTUnwrap(ExerciseStatsCalculator.stat(
            sessionID: UUID(), date: day1,
            sets: [SetSample(weight: 60, unit: .kg, reps: 8), SetSample(weight: 135, unit: .lb, reps: 5)], unit: .kg))
        XCTAssertEqual(first.maxWeight, 61.23, accuracy: 0.01)
        XCTAssertEqual(first.bestOneRepMax, 76, accuracy: 0.01)
        XCTAssertEqual(first.volume, 60 * 8 + 61.235 * 5, accuracy: 0.1)

        // Semana 2: menos peso pero más reps → nuevo récord de 1RM, no de peso máximo.
        let second = try XCTUnwrap(ExerciseStatsCalculator.stat(
            sessionID: UUID(), date: day2, sets: [SetSample(weight: 60, unit: .kg, reps: 12)], unit: .kg))
        let third = try XCTUnwrap(ExerciseStatsCalculator.stat(
            sessionID: UUID(), date: day3, sets: [SetSample(weight: 65, unit: .kg, reps: 3)], unit: .kg))
        let all = [first, second, third]

        let r1 = ExerciseStatsCalculator.isRecord(first, previous: all)
        XCTAssertFalse(r1.weight || r1.oneRepMax, "La primera vez no cuenta como récord")
        let r2 = ExerciseStatsCalculator.isRecord(second, previous: all)
        XCTAssertFalse(r2.weight)
        XCTAssertTrue(r2.oneRepMax)
        let r3 = ExerciseStatsCalculator.isRecord(third, previous: all)
        XCTAssertTrue(r3.weight)
        XCTAssertFalse(r3.oneRepMax)

        let records = ExerciseStatsCalculator.records(all)
        XCTAssertEqual(records.maxWeight, 65)
        XCTAssertEqual(records.maxWeightDate, day3)
        XCTAssertEqual(records.bestOneRepMax, 84, accuracy: 0.01)
        XCTAssertEqual(records.bestOneRepMaxDate, day2)
    }

    func testFormatting() {
        XCTAssertEqual(GymMath.format(62.5, unit: .kg), "62,5 kg")
        XCTAssertEqual(GymMath.duration(3_912), "1:05:12")
        XCTAssertEqual(GymMath.duration(2_883), "48:03")
    }
}

@MainActor
final class WorkoutActionsTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        container = DataStore.makeContainer(inMemory: true)
        context = container.mainContext
        SeedData.seed(context: context)
    }

    private func routine(_ name: String) throws -> Routine {
        try XCTUnwrap(context.fetch(FetchDescriptor<Routine>()).first { $0.name == name })
    }

    func testSeededRoutines() throws {
        let names = try context.fetch(FetchDescriptor<Routine>()).map(\.name).sorted()
        XCTAssertEqual(names, ["Legs", "Pull", "Push"])
        let push = try routine("Push")
        XCTAssertEqual(push.sortedItems.first?.exercise?.name, "Press de banca")
        XCTAssertTrue(push.weekdays.isEmpty, "Sin días asignados")
    }

    func testStartFinishPrefillAndMarkExerciseHabit() throws {
        let push = try routine("Push")
        let monday = Date(timeIntervalSince1970: 1_800_000_000)

        // Primera sesión: sin historial, series vacías con las reps objetivo.
        let first = WorkoutActions.start(routine: push, unit: .kg, in: context, now: monday)
        let bench = try XCTUnwrap(first.sortedExercises.first)
        XCTAssertEqual(bench.sortedSets.count, 4)
        XCTAssertEqual(bench.sortedSets.first?.reps, 8)
        XCTAssertEqual(bench.restSeconds, 150)
        XCTAssertEqual(WorkoutActions.start(routine: nil, unit: .kg, in: context).id, first.id,
                       "Solo puede haber una sesión en curso")

        // Hago dos series del press de banca y nada más.
        for (set, weight) in zip(bench.sortedSets.prefix(2), [80.0, 82.5]) {
            set.weight = weight
            WorkoutActions.toggle(set, in: context, now: monday)
        }
        XCTAssertTrue(WorkoutActions.finish(first, in: context, now: monday.addingTimeInterval(3_600)))
        XCTAssertNotNil(first.endedAt)
        XCTAssertEqual(first.sortedExercises.count, 1, "Los ejercicios sin series hechas se descartan")
        XCTAssertEqual(first.sortedExercises.first?.sortedSets.map(\.weight), [80, 82.5])

        let exerciseHabit = try XCTUnwrap(context.fetch(FetchDescriptor<Habit>()).first { $0.systemRole == HabitSystemRole.exercise })
        XCTAssertTrue(HabitActions.isCompleted(exerciseHabit, on: monday), "Terminar marca el hábito Ejercicio")

        // Segunda sesión: el press de banca viene precargado con lo de la última vez.
        let second = WorkoutActions.start(routine: push, unit: .kg, in: context,
                                          now: monday.addingTimeInterval(7 * 86_400))
        let benchAgain = try XCTUnwrap(second.sortedExercises.first)
        XCTAssertEqual(benchAgain.sortedSets.map(\.weight), [80, 82.5, 82.5, 82.5])
        let last = WorkoutActions.lastPerformance(of: try XCTUnwrap(benchAgain.exercise), before: second, in: context)
        XCTAssertEqual(WorkoutActions.describe(last), "80 kg × 8 · 82,5 × 8")

        // Agregar una serie copia la anterior.
        let added = WorkoutActions.addSet(to: benchAgain, unit: .kg, in: context)
        XCTAssertEqual(added.weight, 82.5)
        XCTAssertEqual(added.order, 4)
    }

    func testFinishingWithNothingDoneDeletesSession() throws {
        let session = WorkoutActions.start(routine: try routine("Legs"), unit: .kg, in: context)
        XCTAssertFalse(WorkoutActions.finish(session, in: context))
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<WorkoutSession>()), 0)
        XCTAssertNil(WorkoutActions.activeSession(in: context))
    }
}
