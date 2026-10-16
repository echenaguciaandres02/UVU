import XCTest
import SwiftData
@testable import UVU

/// "Hoy" es el viernes 16 de octubre de 2026 a las 10:00.
final class TaskScheduleTests: XCTestCase {
    private let calendar = AppCalendar.calendar

    private func date(_ month: Int, _ day: Int, _ hour: Int = 0, _ minute: Int = 0, year: Int = 2026) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: hour, minute: minute))!
    }

    private var now: Date { date(10, 16, 10) }

    func testDailyRecurrenceSkipsPastDays() {
        // Diaria sin hora, vencía hace 3 días: la siguiente es hoy.
        XCTAssertEqual(TaskSchedule.nextDueDate(after: date(10, 13), recurrence: .daily, hasTime: false, now: now),
                       date(10, 16))
        // Diaria con hora 08:00 vencida hoy: hoy ya pasó, la siguiente es mañana a las 08:00.
        XCTAssertEqual(TaskSchedule.nextDueDate(after: date(10, 16, 8), recurrence: .daily, hasTime: true, now: now),
                       date(10, 17, 8))
        // Completada a tiempo: simplemente el día siguiente.
        XCTAssertEqual(TaskSchedule.nextDueDate(after: date(10, 16), recurrence: .daily, hasTime: false, now: now),
                       date(10, 17))
    }

    func testWeeklyAndMonthlyRecurrence() {
        XCTAssertEqual(TaskSchedule.nextDueDate(after: date(10, 16, 18), recurrence: .weekly, hasTime: true, now: now),
                       date(10, 23, 18))
        // Mensual del 31: febrero se ajusta al 28 y marzo vuelve al 31.
        let janNow = date(1, 31, 12, year: 2027)
        XCTAssertEqual(TaskSchedule.nextDueDate(after: date(1, 31, year: 2027), recurrence: .monthly,
                                                hasTime: false, now: janNow),
                       date(2, 28, year: 2027))
        XCTAssertEqual(TaskSchedule.nextDueDate(after: date(1, 31, year: 2027), recurrence: .monthly,
                                                hasTime: false, now: date(3, 1, 9, year: 2027)),
                       date(3, 31, year: 2027))
        XCTAssertNil(TaskSchedule.nextDueDate(after: now, recurrence: .none, hasTime: false, now: now))
    }

    func testReminderDate() {
        // Sin hora: 9:00 del día límite (por defecto), menos la anticipación.
        XCTAssertEqual(TaskSchedule.reminderDate(due: date(10, 20), hasTime: false, reminderEnabled: true,
                                                 offsetMinutes: 0, defaultMinutes: 540),
                       date(10, 20, 9))
        XCTAssertEqual(TaskSchedule.reminderDate(due: date(10, 20, 15, 30), hasTime: true, reminderEnabled: true,
                                                 offsetMinutes: 30, defaultMinutes: 540),
                       date(10, 20, 15))
        XCTAssertEqual(TaskSchedule.reminderDate(due: date(10, 20, 15), hasTime: true, reminderEnabled: true,
                                                 offsetMinutes: 1440, defaultMinutes: 540),
                       date(10, 19, 15))
        XCTAssertNil(TaskSchedule.reminderDate(due: date(10, 20), hasTime: false, reminderEnabled: false,
                                               offsetMinutes: 0, defaultMinutes: 540))
        XCTAssertNil(TaskSchedule.reminderDate(due: nil, hasTime: false, reminderEnabled: true,
                                               offsetMinutes: 0, defaultMinutes: 540))
    }

    func testOverdueAndDescriptions() {
        XCTAssertTrue(TaskSchedule.isOverdue(due: date(10, 16, 9), hasTime: true, isCompleted: false, now: now))
        XCTAssertFalse(TaskSchedule.isOverdue(due: date(10, 16), hasTime: false, isCompleted: false, now: now),
                       "Sin hora, vence al final del día: hoy no está atrasada")
        XCTAssertTrue(TaskSchedule.isOverdue(due: date(10, 15), hasTime: false, isCompleted: false, now: now))
        XCTAssertFalse(TaskSchedule.isOverdue(due: date(10, 15), hasTime: false, isCompleted: true, now: now))

        XCTAssertEqual(TaskSchedule.dueDescription(due: date(10, 16, 15), hasTime: true, now: now), "HOY 15:00")
        XCTAssertEqual(TaskSchedule.dueDescription(due: date(10, 17), hasTime: false, now: now), "MAÑANA")
        XCTAssertEqual(TaskSchedule.dueDescription(due: date(10, 15), hasTime: false, now: now), "AYER")
    }
}

@MainActor
final class TaskActionsTests: XCTestCase {
    private let calendar = AppCalendar.calendar
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        container = DataStore.makeContainer(inMemory: true)
        context = container.mainContext
    }

    private func date(_ month: Int, _ day: Int, _ hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    private func makeTask(_ title: String, due: Date?, recurrence: TaskRecurrence = .none, list: TaskList? = nil) -> TaskItem {
        let task = TaskItem(title: title, dueDate: due)
        task.recurrence = recurrence
        context.insert(task)
        task.list = list
        return task
    }

    func testCompletingRecurringTaskCreatesNextOccurrence() throws {
        let list = TaskList(name: "Universidad", symbol: "graduationcap.fill", colorHex: "AF52DE")
        context.insert(list)
        let task = makeTask("Repasar apuntes", due: date(10, 16), recurrence: .weekly, list: list)
        task.priority = .high
        for (index, title) in ["Leer", "Resumir"].enumerated() {
            let subtask = Subtask(title: title, order: index)
            subtask.isDone = true
            context.insert(subtask)
            subtask.task = task
        }

        let next = try XCTUnwrap(TaskActions.complete(task, in: context, now: date(10, 16, 10)))

        XCTAssertTrue(task.isCompleted)
        XCTAssertNotNil(task.completedAt)
        XCTAssertFalse(next.isCompleted)
        XCTAssertEqual(next.dueDate, date(10, 23))
        XCTAssertEqual(next.list?.id, list.id)
        XCTAssertEqual(next.priority, .high)
        XCTAssertEqual(next.recurrence, .weekly)
        XCTAssertEqual(next.sortedSubtasks.map(\.title), ["Leer", "Resumir"])
        XCTAssertTrue(next.sortedSubtasks.allSatisfy { !$0.isDone }, "Las subtareas vuelven sin marcar")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<TaskItem>()), 2)
    }

    func testCompletingSimpleTaskDoesNotCreateAnother() {
        let task = makeTask("Pagar luz", due: date(10, 16))
        XCTAssertNil(TaskActions.complete(task, in: context, now: date(10, 16, 10)))
        XCTAssertTrue(task.isCompleted)

        TaskActions.reopen(task, in: context)
        XCTAssertFalse(task.isCompleted)
        XCTAssertNil(task.completedAt)
    }

    func testScopesGroupTasks() {
        let now = date(10, 16, 10)
        let overdue = makeTask("Atrasada", due: date(10, 14))
        let today = makeTask("De hoy", due: date(10, 16, 18))
        let tomorrow = makeTask("Mañana", due: date(10, 17))
        let later = makeTask("Más adelante", due: date(10, 30))
        let undated = makeTask("Sin fecha", due: nil)
        let done = makeTask("Hecha", due: date(10, 15))
        done.isCompleted = true
        done.completedAt = date(10, 15, 20)
        let all = [overdue, today, tomorrow, later, undated, done]

        let todaySections = TaskGrouping.sections(for: .today, tasks: all, now: now)
        XCTAssertEqual(todaySections.map(\.title), ["Atrasadas", "Hoy"])
        XCTAssertEqual(todaySections.map { $0.tasks.map(\.title) }, [["Atrasada"], ["De hoy"]])

        let upcoming = TaskGrouping.sections(for: .upcoming, tasks: all, now: now)
        XCTAssertEqual(upcoming.flatMap { $0.tasks.map(\.title) }, ["Mañana", "Más adelante"])
        XCTAssertEqual(upcoming.first?.title, "MAÑANA")

        let allSections = TaskGrouping.sections(for: .all, tasks: all, now: now)
        XCTAssertEqual(allSections.flatMap { $0.tasks.map(\.title) },
                       ["Atrasada", "De hoy", "Mañana", "Más adelante", "Sin fecha"])

        let completed = TaskGrouping.sections(for: .completed, tasks: all, now: now)
        XCTAssertEqual(completed.flatMap { $0.tasks.map(\.title) }, ["Hecha"])
    }
}
