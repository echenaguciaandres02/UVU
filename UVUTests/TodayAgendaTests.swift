import XCTest
import SwiftData
@testable import UVU

@MainActor
final class TodayAgendaTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private var now: Date!

    override func setUp() async throws {
        container = DataStore.makeContainer(inMemory: true)
        context = container.mainContext
        // Hoy a las 10:00.
        now = AppCalendar.calendar.date(byAdding: .hour, value: 10, to: AppCalendar.startOfDay(.now))
    }

    private func habit(_ name: String, reminders: [Int]) -> Habit {
        let habit = Habit(name: name, symbol: "drop.fill", colorHex: "4A90D9")
        habit.createdAt = now.addingTimeInterval(-10 * 86_400)
        habit.reminderMinutes = reminders
        context.insert(habit)
        return habit
    }

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        AppCalendar.calendar.date(byAdding: .minute, value: hour * 60 + minute, to: AppCalendar.startOfDay(now))!
    }

    func testRemindersKeepOnlyWhatIsLeftTodayInOrder() throws {
        let water = habit("Tomar agua", reminders: [8 * 60, 12 * 60, 18 * 60])
        let done = habit("Creatina", reminders: [15 * 60])
        HabitActions.setValue(1, for: done, on: now, in: context)

        let call = TaskItem(title: "Llamar", dueDate: at(16, 30), hasTime: true)
        call.reminderOffsetMinutes = 30
        let finished = TaskItem(title: "Hecha", dueDate: at(11), hasTime: true)
        finished.isCompleted = true
        let tomorrow = TaskItem(title: "Mañana", dueDate: at(34), hasTime: true)
        let silent = TaskItem(title: "Sin aviso", dueDate: at(13), hasTime: true)
        silent.reminderEnabled = false
        for task in [call, finished, tomorrow, silent] { context.insert(task) }
        try context.save()

        let reminders = TodayAgenda.upcomingReminders(habits: [water, done],
                                                      tasks: [call, finished, tomorrow, silent], now: now)

        // 8:00 ya pasó; la creatina está cumplida; la tarea hecha, la de mañana y la sin aviso no cuentan.
        XCTAssertEqual(reminders.map(\.title), ["Tomar agua", "Llamar", "Tomar agua"])
        XCTAssertEqual(reminders.map(\.date), [at(12), at(16), at(18)])
        XCTAssertEqual(reminders.map(\.kind), [.habit, .task, .habit])
    }

    func testTaskWithoutTimeUsesDefaultHour() throws {
        let task = TaskItem(title: "Pagar", dueDate: AppCalendar.startOfDay(now), hasTime: false)
        context.insert(task)

        let early = TodayAgenda.upcomingReminders(habits: [], tasks: [task], now: now, defaultTaskMinutes: 9 * 60)
        XCTAssertTrue(early.isEmpty, "El aviso de las 9:00 ya sonó a las 10:00")

        let late = TodayAgenda.upcomingReminders(habits: [], tasks: [task], now: now, defaultTaskMinutes: 20 * 60)
        XCTAssertEqual(late.first?.date, at(20))
    }

    func testTodayHabitsPutPendingFirst() throws {
        let first = habit("Primero", reminders: [])
        first.sortOrder = 0
        let second = habit("Segundo", reminders: [])
        second.sortOrder = 1
        HabitActions.setValue(1, for: first, on: now, in: context)

        XCTAssertEqual(TodayAgenda.todayHabits([first, second], now: now).map(\.name), ["Segundo", "Primero"])
    }

    func testDayActivityIndexGroupsByDay() throws {
        let yesterday = now.addingTimeInterval(-86_400)
        let session = WorkoutSession(startedAt: yesterday)
        session.endedAt = yesterday.addingTimeInterval(3_600)
        let running = WorkoutSession(startedAt: now)
        let task = TaskItem(title: "Entregar")
        task.isCompleted = true
        task.completedAt = now
        let entry = JournalEntry(date: AppCalendar.startOfDay(yesterday))
        for item in [session, running] { context.insert(item) }
        context.insert(task)
        context.insert(entry)

        let index = DayActivityIndex(sessions: [session, running], tasks: [task], entries: [entry])

        XCTAssertEqual(index.workouts(on: yesterday).count, 1)
        XCTAssertTrue(index.workouts(on: now).isEmpty, "Un entreno en curso no cuenta")
        XCTAssertEqual(index.completedTasks(on: now).map(\.title), ["Entregar"])
        XCTAssertNotNil(index.journalEntry(on: yesterday))
        XCTAssertNil(index.journalEntry(on: now))
    }
}
