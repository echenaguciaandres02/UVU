import XCTest
import SwiftData
@testable import UVU

/// Copia exacta de cómo eran los hábitos en la fase 2 (antes de `reminderMinutes`),
/// guardada con un plan de migración como lo hacía esa versión de la app.
enum Phase2Schema: VersionedSchema {
    static var versionIdentifier: Schema.Version { Schema.Version(1, 0, 0) }
    static var models: [any PersistentModel.Type] { [Habit.self, HabitEntry.self] }

    @Model
    final class Habit {
        var id: UUID = UUID()
        var name: String = ""
        var symbol: String = "checkmark.circle.fill"
        var colorHex: String = "34C759"
        var kindRaw: String = "binary"
        var target: Double = 1
        var unit: String = ""
        var frequencyRaw: String = "daily"
        var weekdays: [Int] = []
        var timesPerWeek: Int = 3
        var reminderHour: Int? = nil
        var reminderMinute: Int? = nil
        var systemRole: String? = nil
        var sortOrder: Int = 0
        var isArchived: Bool = false
        var createdAt: Date = Date()

        @Relationship(deleteRule: .cascade, inverse: \HabitEntry.habit)
        var entries: [HabitEntry]? = []

        init(name: String) {
            self.name = name
        }
    }

    @Model
    final class HabitEntry {
        var id: UUID = UUID()
        var date: Date = Date()
        var value: Double = 0
        var habit: Habit?

        init(date: Date, value: Double) {
            self.date = date
            self.value = value
        }
    }
}

enum Phase2MigrationPlan: SchemaMigrationPlan {
    static var schemas: [any VersionedSchema.Type] { [Phase2Schema.self] }
    static var stages: [MigrationStage] { [] }
}

@MainActor
final class MigrationTests: XCTestCase {

    func testPhase2StoreOpensWithCurrentModelsWithoutLosingData() throws {
        let folder = FileManager.default.temporaryDirectory.appending(path: "uvu-migration-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appending(path: "UVU.store")
        defer { try? FileManager.default.removeItem(at: folder) }

        // 1. Base creada por la versión anterior.
        do {
            let schema = Schema(versionedSchema: Phase2Schema.self)
            let container = try ModelContainer(
                for: schema, migrationPlan: Phase2MigrationPlan.self,
                configurations: ModelConfiguration(schema: schema, url: url, cloudKitDatabase: .none)
            )
            let context = container.mainContext
            let habit = Phase2Schema.Habit(name: "Tomar agua")
            habit.reminderHour = 9
            habit.reminderMinute = 30
            context.insert(habit)
            for offset in 0..<3 {
                let entry = Phase2Schema.HabitEntry(date: Date(timeIntervalSince1970: Double(offset) * 86_400), value: 8)
                context.insert(entry)
                entry.habit = habit
            }
            try context.save()
        }

        // 2. La versión nueva la abre sin apartarla y conserva todo.
        let container = DataStore.makeContainer(url: url)
        XCTAssertNil(DataStore.setAsideStoreURL, "La base se tuvo que apartar: la migración falló")

        let context = container.mainContext
        let habits = try context.fetch(FetchDescriptor<UVU.Habit>())
        XCTAssertEqual(habits.count, 1)
        let habit = try XCTUnwrap(habits.first)
        XCTAssertEqual(habit.name, "Tomar agua")
        XCTAssertEqual(habit.entries?.count, 3)
        XCTAssertEqual(habit.reminderHour, 9)
        XCTAssertEqual(habit.reminderMinutes, [])

        // 3. El recordatorio antiguo pasa a la lista nueva.
        DataUpgrades.moveLegacyReminders(context: context)
        XCTAssertEqual(habit.reminderMinutes, [9 * 60 + 30])
        XCTAssertNil(habit.reminderHour)
    }

    func testOldBackupWithSingleReminderIsImported() throws {
        let container = DataStore.makeContainer(inMemory: true)
        let context = container.mainContext
        let json = """
        {"app":"UVU","version":1,"exportedAt":"2026-10-16T12:00:00Z",
         "habits":[{"id":"11111111-1111-1111-1111-111111111111","name":"Agua","symbol":"drop.fill",
           "colorHex":"007AFF","kind":"quantity","target":8,"unit":"vasos","frequency":"daily",
           "weekdays":[],"timesPerWeek":3,"reminderHour":8,"reminderMinute":15,"sortOrder":0,
           "isArchived":false,"createdAt":"2026-10-01T12:00:00Z","entries":[]}],
         "taskLists":[],"journalEntries":[],"exercises":[],"routines":[],"sessions":[]}
        """
        try BackupService.restore(BackupService.decode(Data(json.utf8)), into: context)

        let habit = try XCTUnwrap(context.fetch(FetchDescriptor<UVU.Habit>()).first)
        XCTAssertEqual(habit.reminderMinutes, [8 * 60 + 15])
    }

    func testSpreadReminders() {
        XCTAssertEqual(ReminderTime.spread(from: 8 * 60, to: 20 * 60, every: 120),
                       [480, 600, 720, 840, 960, 1080, 1200])
        XCTAssertEqual(ReminderTime.spread(from: 0, to: 23 * 60, every: 30).count, ReminderTime.maxPerHabit)
        XCTAssertEqual(ReminderTime.spread(from: 600, to: 500, every: 60), [600])
    }
}
