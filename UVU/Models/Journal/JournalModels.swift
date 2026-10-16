import Foundation
import SwiftData

@Model
final class JournalEntry {
    var id: UUID = UUID()
    /// Inicio del día. La app garantiza una sola entrada por día.
    var date: Date = Date()
    var text: String = ""
    /// Estado de ánimo del 1 (muy mal) al 5 (muy bien).
    var mood: Int = 3
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    @Relationship(deleteRule: .cascade, inverse: \PromptAnswer.entry)
    var answers: [PromptAnswer]? = []

    @Relationship(inverse: \JournalTag.entries)
    var tags: [JournalTag]? = []

    init(date: Date, text: String = "", mood: Int = 3) {
        self.date = AppCalendar.startOfDay(date)
        self.text = text
        self.mood = mood
    }
}

/// Respuesta a una pregunta guía ("¿Qué salió bien hoy?").
@Model
final class PromptAnswer {
    var id: UUID = UUID()
    var question: String = ""
    var answer: String = ""
    var order: Int = 0
    var entry: JournalEntry?

    init(question: String, answer: String, order: Int = 0) {
        self.question = question
        self.answer = answer
        self.order = order
    }
}

@Model
final class JournalTag {
    var id: UUID = UUID()
    var name: String = ""
    var entries: [JournalEntry]? = []

    init(name: String) {
        self.name = name
    }
}
