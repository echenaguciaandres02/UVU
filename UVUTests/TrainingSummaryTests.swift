import XCTest
@testable import UVU

final class TrainingSummaryTests: XCTestCase {
    private let calendar = AppCalendar.calendar
    private let bench = UUID()
    private let squat = UUID()
    private let curl = UUID()

    private func day(_ year: Int, _ month: Int, _ day: Int) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 18))!
    }

    private func sets(_ count: Int, _ date: Date, _ muscle: MuscleGroup, _ id: UUID, _ name: String,
                      weight: Double = 50, reps: Int = 10) -> [TrainingSet] {
        Array(repeating: TrainingSet(date: date, muscle: muscle, exerciseID: id, exerciseName: name,
                                     weight: weight, reps: reps), count: count)
    }

    func testMonthSharesComparedWithPreviousMonth() {
        let data = sets(4, day(2026, 9, 10), .chest, bench, "Press de banca")
            + sets(6, day(2026, 10, 2), .chest, bench, "Press de banca")
            + sets(3, day(2026, 10, 5), .legs, squat, "Sentadilla")
            + sets(1, day(2026, 10, 6), .biceps, curl, "Curl")
            + sets(2, day(2026, 9, 12), .back, UUID(), "Remo")

        let shares = TrainingSummary.shares(data, period: .month, containing: day(2026, 10, 17))

        XCTAssertEqual(shares.map(\.muscle), [.chest, .legs, .biceps, .back])
        XCTAssertEqual(shares.map(\.sets), [6, 3, 1, 0])
        XCTAssertEqual(shares[0].fraction, 0.6, accuracy: 0.0001)
        XCTAssertEqual(shares[0].change ?? 0, 0.5, accuracy: 0.0001, "6 series frente a 4: +50 %")
        XCTAssertNil(shares[1].change, "Las piernas no se entrenaron el mes anterior")
        XCTAssertEqual(shares[3].change ?? 0, -1, accuracy: 0.0001, "Espalda: de 2 a 0")
        XCTAssertEqual(TrainingSummary.totalSets(data, period: .month, containing: day(2026, 10, 17)), 10)
    }

    func testYearAccumulatesAllMonths() {
        let data = sets(4, day(2026, 1, 10), .chest, bench, "Press de banca")
            + sets(6, day(2026, 10, 2), .legs, squat, "Sentadilla")
            + sets(5, day(2025, 12, 30), .chest, bench, "Press de banca")

        let shares = TrainingSummary.shares(data, period: .year, containing: day(2026, 10, 17))
        XCTAssertEqual(shares.map(\.muscle), [.legs, .chest])
        XCTAssertEqual(shares.map(\.sets), [6, 4])
        XCTAssertEqual(shares[1].previousSets, 5, "El pecho de diciembre de 2025 cuenta para el año anterior")

        let months = TrainingSummary.monthlyTotals(data, year: day(2026, 10, 17))
        XCTAssertEqual(months.count, 12)
        XCTAssertEqual(months[0].sets, 4)
        XCTAssertEqual(months[9].sets, 6)
        XCTAssertEqual(months.map(\.sets).reduce(0, +), 10)
    }

    func testProgressNeedsHistoryAndAnImprovement() {
        let data = sets(3, day(2026, 9, 10), .chest, bench, "Press de banca", weight: 60, reps: 8)
            + sets(1, day(2026, 10, 3), .chest, bench, "Press de banca", weight: 65, reps: 5)
            // Primera vez este mes: no cuenta como progreso.
            + sets(3, day(2026, 10, 4), .legs, squat, "Sentadilla", weight: 100, reps: 5)
            // Mismo peso, más repeticiones: sube solo el 1RM.
            + sets(1, day(2026, 9, 1), .biceps, curl, "Curl", weight: 15, reps: 8)
            + sets(1, day(2026, 10, 8), .biceps, curl, "Curl", weight: 15, reps: 12)

        let progress = TrainingSummary.progress(data, period: .month, containing: day(2026, 10, 17))

        XCTAssertEqual(progress.map(\.name), ["Curl", "Press de banca"])
        let benchProgress = progress[1]
        XCTAssertEqual(benchProgress.weightGain ?? 0, 5, accuracy: 0.0001)
        XCTAssertNil(benchProgress.oneRepMaxGain, "65 × 5 (75,8) no supera 60 × 8 (76)")
        let curlProgress = progress[0]
        XCTAssertNil(curlProgress.weightGain)
        XCTAssertEqual(curlProgress.oneRepMaxGain ?? 0, 15 * (1 + 12.0 / 30) - 15 * (1 + 8.0 / 30), accuracy: 0.0001)
    }
}
