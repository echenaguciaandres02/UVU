import Foundation
import SwiftData
import SwiftUI

/// Estado de ánimo del 1 al 5.
enum Mood {
    static let range = 1...5

    static func title(_ level: Int) -> String {
        switch level {
        case 1: return "Muy mal"
        case 2: return "Mal"
        case 3: return "Normal"
        case 4: return "Bien"
        default: return "Muy bien"
        }
    }

    /// Gris que se aclara con el ánimo: 1 = graphite oscuro … 5 = bone. El rojo queda para "completado".
    static func shade(_ level: Int) -> Color {
        let clamped = Double(min(max(level, 1), 5))
        let t = (clamped - 1) / 4
        // De #2A2A2A (graphite) a #E9E3D6 (bone).
        let red = (42 + (233 - 42) * t) / 255
        let green = (42 + (227 - 42) * t) / 255
        let blue = (42 + (214 - 42) * t) / 255
        return Color(.sRGB, red: red, green: green, blue: blue, opacity: 1)
    }

    /// Texto que se lee sobre `shade(level)`.
    static func numberColor(_ level: Int) -> Color {
        level >= 4 ? .ink : .bone
    }
}

/// Preguntas guía del journal (editables en Ajustes).
enum JournalPrompts {
    static let storageKey = "journal.prompts"

    static let defaults = [
        "¿Qué salió bien hoy?",
        "¿Qué voy a mejorar mañana?",
        "¿Por qué estoy agradecido hoy?",
    ]

    static func decode(_ raw: String) -> [String] {
        guard let data = raw.data(using: .utf8),
              let list = try? JSONDecoder().decode([String].self, from: data) else { return defaults }
        return list
    }

    static func encode(_ list: [String]) -> String {
        let data = (try? JSONEncoder().encode(list)) ?? Data("[]".utf8)
        return String(decoding: data, as: UTF8.self)
    }

    static var current: [String] {
        guard let raw = UserDefaults.standard.string(forKey: storageKey) else { return defaults }
        return decode(raw)
    }
}

/// Operaciones del journal: una entrada por día, etiquetas sin duplicados y búsqueda.
@MainActor
enum JournalStore {

    static func entry(on day: Date, in context: ModelContext) -> JournalEntry? {
        let start = AppCalendar.startOfDay(day)
        let end = AppCalendar.calendar.date(byAdding: .day, value: 1, to: start) ?? start
        var descriptor = FetchDescriptor<JournalEntry>(predicate: #Predicate { $0.date >= start && $0.date < end })
        descriptor.fetchLimit = 1
        return try? context.fetch(descriptor).first
    }

    /// Devuelve la entrada del día o crea una nueva (nunca dos para el mismo día).
    static func entryOrNew(on day: Date, in context: ModelContext) -> JournalEntry {
        if let existing = entry(on: day, in: context) { return existing }
        let entry = JournalEntry(date: day)
        context.insert(entry)
        return entry
    }

    /// Busca la etiqueta por nombre (sin distinguir mayúsculas ni tildes) o la crea.
    static func tag(named rawName: String, in context: ModelContext) -> JournalTag? {
        let name = normalizedTagName(rawName)
        guard !name.isEmpty else { return nil }
        let all = (try? context.fetch(FetchDescriptor<JournalTag>())) ?? []
        if let existing = all.first(where: { sameTag($0.name, name) }) { return existing }
        let tag = JournalTag(name: name)
        context.insert(tag)
        return tag
    }

    static func normalizedTagName(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "#"))
            .lowercased()
    }

    static func sameTag(_ lhs: String, _ rhs: String) -> Bool {
        lhs.compare(rhs, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
    }

    /// Guarda texto, ánimo, respuestas y etiquetas. Las respuestas vacías no se guardan.
    static func save(_ entry: JournalEntry, text: String, mood: Int, answers: [(question: String, answer: String)],
                     tagNames: [String], in context: ModelContext) {
        entry.text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        entry.mood = min(max(mood, 1), 5)
        entry.updatedAt = .now

        for old in entry.answers ?? [] {
            context.delete(old)
        }
        let filled = answers.filter { !$0.answer.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        for (index, item) in filled.enumerated() {
            let answer = PromptAnswer(question: item.question,
                                      answer: item.answer.trimmingCharacters(in: .whitespacesAndNewlines),
                                      order: index)
            context.insert(answer)
            answer.entry = entry
        }

        var tags: [JournalTag] = []
        for name in tagNames {
            let normalized = normalizedTagName(name)
            guard !tags.contains(where: { sameTag($0.name, normalized) }),
                  let tag = tag(named: normalized, in: context) else { continue }
            tags.append(tag)
        }
        entry.tags = tags
        try? context.save()
        deleteUnusedTags(in: context)
    }

    static func delete(_ entry: JournalEntry, in context: ModelContext) {
        context.delete(entry)
        try? context.save()
        deleteUnusedTags(in: context)
    }

    static func deleteUnusedTags(in context: ModelContext) {
        let all = (try? context.fetch(FetchDescriptor<JournalTag>())) ?? []
        for tag in all where (tag.entries ?? []).isEmpty {
            context.delete(tag)
        }
        try? context.save()
    }

    /// Filtra por texto (en el texto, las respuestas y las etiquetas) y por etiqueta exacta.
    static func filter(_ entries: [JournalEntry], query: String, tag: String?) -> [JournalEntry] {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return entries.filter { entry in
            let tagNames = (entry.tags ?? []).map(\.name)
            if let tag, !tagNames.contains(where: { sameTag($0, tag) }) { return false }
            guard !trimmed.isEmpty else { return true }
            let haystack = ([entry.text] + (entry.answers ?? []).map(\.answer) + tagNames).joined(separator: " ")
            return haystack.localizedStandardContains(trimmed)
        }
    }
}

extension JournalEntry {
    var sortedAnswers: [PromptAnswer] {
        (answers ?? []).sorted { $0.order < $1.order }
    }

    var sortedTagNames: [String] {
        (tags ?? []).map(\.name).sorted()
    }

    /// Primer texto disponible para mostrar en la lista.
    var excerpt: String {
        if !text.isEmpty { return text }
        return sortedAnswers.first?.answer ?? ""
    }
}
