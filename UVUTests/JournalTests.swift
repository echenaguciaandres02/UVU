import XCTest
import SwiftData
import SwiftUI
@testable import UVU

@MainActor
final class JournalTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!
    private let calendar = AppCalendar.calendar

    override func setUp() async throws {
        container = DataStore.makeContainer(inMemory: true)
        context = container.mainContext
    }

    private func day(_ value: Int, hour: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 10, day: value, hour: hour))!
    }

    func testOneEntryPerDay() throws {
        let morning = JournalStore.entryOrNew(on: day(16, hour: 7), in: context)
        try context.save()
        let night = JournalStore.entryOrNew(on: day(16, hour: 23), in: context)

        XCTAssertEqual(morning.id, night.id, "El mismo día devuelve la misma entrada")
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalEntry>()), 1)
        XCTAssertNil(JournalStore.entry(on: day(17), in: context))
    }

    func testSaveKeepsOnlyFilledAnswersAndDeduplicatesTags() throws {
        let entry = JournalStore.entryOrNew(on: day(16), in: context)
        JournalStore.save(entry, text: "  Buen entreno.  ", mood: 9,
                          answers: [("¿Qué salió bien hoy?", "Entrené a las 5"), ("¿Qué voy a mejorar mañana?", "  ")],
                          tagNames: ["Gym", "#gym", "Tesis", " tésis "], in: context)

        XCTAssertEqual(entry.text, "Buen entreno.")
        XCTAssertEqual(entry.mood, 5, "El ánimo se limita a 1…5")
        XCTAssertEqual(entry.sortedAnswers.map(\.question), ["¿Qué salió bien hoy?"])
        XCTAssertEqual(entry.sortedTagNames, ["gym", "tesis"])
        XCTAssertEqual(try context.fetchCount(FetchDescriptor<JournalTag>()), 2)

        // Al quitar una etiqueta de la única entrada que la usaba, la etiqueta desaparece.
        JournalStore.save(entry, text: entry.text, mood: 4, answers: [], tagNames: ["gym"], in: context)
        XCTAssertEqual(try context.fetch(FetchDescriptor<JournalTag>()).map(\.name), ["gym"])
        XCTAssertTrue(entry.sortedAnswers.isEmpty)
    }

    func testSearchByTextAnswerTagAndAccents() {
        let first = JournalStore.entryOrNew(on: day(14), in: context)
        JournalStore.save(first, text: "Día pesado en el trabajo", mood: 2, answers: [], tagNames: ["trabajo"], in: context)
        let second = JournalStore.entryOrNew(on: day(15), in: context)
        JournalStore.save(second, text: "", mood: 4,
                          answers: [("¿Qué salió bien hoy?", "Terminé el capítulo")], tagNames: ["tesis"], in: context)
        let entries = [first, second]

        XCTAssertEqual(JournalStore.filter(entries, query: "dia", tag: nil).map(\.id), [first.id], "Ignora tildes")
        XCTAssertEqual(JournalStore.filter(entries, query: "capítulo", tag: nil).map(\.id), [second.id], "Busca en respuestas")
        XCTAssertEqual(JournalStore.filter(entries, query: "", tag: "TESIS").map(\.id), [second.id], "Filtra por etiqueta")
        XCTAssertEqual(JournalStore.filter(entries, query: "trabajo", tag: "tesis").count, 0)
        XCTAssertEqual(JournalStore.filter(entries, query: "  ", tag: nil).count, 2)
        XCTAssertEqual(second.excerpt, "Terminé el capítulo", "Sin texto, el extracto es la primera respuesta")
    }

    func testMoodShadesGetLighterAndPromptsRoundTrip() {
        var previous: CGFloat = -1
        for level in Mood.range {
            var white: CGFloat = 0, alpha: CGFloat = 0
            UIColor(Mood.shade(level)).getWhite(&white, alpha: &alpha)
            XCTAssertGreaterThan(white, previous, "Ánimo \(level) debe ser más claro que el anterior")
            previous = white
        }
        XCTAssertEqual(Mood.title(1), "Muy mal")
        XCTAssertEqual(Mood.title(5), "Muy bien")

        let custom = ["¿Qué aprendí?", "¿Qué me dio energía?"]
        XCTAssertEqual(JournalPrompts.decode(JournalPrompts.encode(custom)), custom)
        XCTAssertEqual(JournalPrompts.decode("no es json"), JournalPrompts.defaults)
    }
}
