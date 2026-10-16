import XCTest
@testable import UVU

/// Fechas de referencia: viernes 16 de octubre de 2026 es "hoy".
/// La semana va de lunes 12 a domingo 18.
final class HabitEvaluatorTests: XCTestCase {

    private func day(_ month: Int, _ day: Int) -> Date {
        AppCalendar.calendar.date(from: DateComponents(year: 2026, month: month, day: day))!
    }

    private var today: Date { day(10, 16) }

    private func rules(
        _ kind: HabitKind = .binary,
        target: Double = 1,
        frequency: HabitFrequency = .daily,
        weekdays: Set<Int> = [],
        timesPerWeek: Int = 3,
        createdAt: Date
    ) -> HabitRules {
        HabitRules(kind: kind, target: target, frequency: frequency, weekdays: weekdays,
                   timesPerWeek: timesPerWeek, createdAt: createdAt)
    }

    private func values(_ days: [(Int, Int)], value: Double = 1) -> [Date: Double] {
        Dictionary(uniqueKeysWithValues: days.map { (day($0.0, $0.1), value) })
    }

    func testDailyStreaksAndStatuses() {
        let done = values([(10, 3), (10, 4)] + (10...16).map { (10, $0) })
        let evaluator = HabitEvaluator(rules: rules(createdAt: day(10, 1)), values: done, today: today)

        XCTAssertEqual(evaluator.currentStreak(), 7)
        XCTAssertEqual(evaluator.bestStreak(), 7)
        XCTAssertEqual(evaluator.status(on: day(10, 9)), .failed)
        XCTAssertEqual(evaluator.status(on: day(10, 16)), .completed)
        XCTAssertEqual(evaluator.status(on: day(10, 17)), .future)
        XCTAssertEqual(evaluator.status(on: day(9, 30)), .notApplicable, "Antes de crear el hábito es gris")
    }

    func testTodayPendingDoesNotBreakStreak() {
        let done = values((10...15).map { (10, $0) })
        let evaluator = HabitEvaluator(rules: rules(createdAt: day(10, 1)), values: done, today: today)

        XCTAssertEqual(evaluator.status(on: today), .pending)
        XCTAssertEqual(evaluator.currentStreak(), 6)
    }

    func testQuantityPartialAndWeeklyRate() {
        var amounts: [Date: Double] = [:]
        amounts[day(10, 14)] = 8
        amounts[day(10, 15)] = 4
        amounts[today] = 3
        let evaluator = HabitEvaluator(rules: rules(.quantity, target: 8, createdAt: day(10, 1)),
                                       values: amounts, today: today)

        XCTAssertEqual(evaluator.status(on: day(10, 14)), .completed)
        XCTAssertEqual(evaluator.status(on: day(10, 15)), .partial)
        XCTAssertEqual(evaluator.status(on: today), .partial)
        XCTAssertEqual(evaluator.currentStreak(), 0)
        // Lun 0 + Mar 0 + Mié 1 + Jue 0,5 + Vie 0,375 → 1,875 / 5
        XCTAssertEqual(evaluator.weeklyRate(containing: today) ?? -1, 1.875 / 5, accuracy: 0.0001)
    }

    func testSpecificDaysSkipsOtherDays() {
        let done = values([(10, 5), (10, 7), (10, 9), (10, 12), (10, 14)])
        let evaluator = HabitEvaluator(
            rules: rules(frequency: .specificDays, weekdays: [2, 4, 6], createdAt: day(10, 1)),
            values: done, today: today
        )

        XCTAssertEqual(evaluator.status(on: day(10, 13)), .notApplicable, "El martes no toca")
        XCTAssertEqual(evaluator.status(on: day(10, 2)), .failed)
        XCTAssertEqual(evaluator.status(on: today), .pending)
        XCTAssertEqual(evaluator.currentStreak(), 5)
        XCTAssertEqual(evaluator.bestStreak(), 5)
    }

    func testTimesPerWeek() {
        let done = values([(9, 28), (9, 30), (10, 2), (10, 6), (10, 12), (10, 13)])
        let evaluator = HabitEvaluator(
            rules: rules(frequency: .timesPerWeek, timesPerWeek: 3, createdAt: day(9, 28)),
            values: done, today: today
        )

        XCTAssertEqual(evaluator.status(on: day(9, 29)), .notApplicable, "Semana cumplida: los días libres son grises")
        XCTAssertEqual(evaluator.status(on: day(10, 7)), .failed, "Semana terminada sin la meta: rojo")
        XCTAssertEqual(evaluator.status(on: day(10, 14)), .notApplicable, "Aún se puede cumplir esta semana")
        XCTAssertEqual(evaluator.status(on: today), .pending)
        XCTAssertEqual(evaluator.currentStreak(), 0)
        XCTAssertEqual(evaluator.bestStreak(), 1)
        XCTAssertEqual(evaluator.weeklyRate(containing: today) ?? -1, 2.0 / 3.0, accuracy: 0.0001)
    }

    func testTimesPerWeekUnreachableGoalTurnsRed() {
        let done = values([(10, 12), (10, 13)])
        let evaluator = HabitEvaluator(
            rules: rules(frequency: .timesPerWeek, timesPerWeek: 6, createdAt: day(10, 1)),
            values: done, today: today
        )

        XCTAssertEqual(evaluator.status(on: day(10, 14)), .failed)
        XCTAssertEqual(evaluator.status(on: today), .pending, "Hoy nunca se pinta de rojo")
    }

    func testCombinedStatus() {
        let first = HabitEvaluator(rules: rules(createdAt: day(10, 1)),
                                   values: values([(10, 14), (10, 15)]), today: today)
        let second = HabitEvaluator(rules: rules(createdAt: day(10, 1)),
                                    values: values([(10, 14)]), today: today)
        let both = [first, second]

        XCTAssertEqual(HabitSummary.combinedStatus(both, on: day(10, 14), today: today), .completed)
        XCTAssertEqual(HabitSummary.combinedStatus(both, on: day(10, 15), today: today), .partial)
        XCTAssertEqual(HabitSummary.combinedStatus(both, on: day(10, 13), today: today), .failed)
        XCTAssertEqual(HabitSummary.combinedStatus(both, on: today, today: today), .pending)
        XCTAssertEqual(HabitSummary.combinedStatus(both, on: day(10, 20), today: today), .future)
    }
}
