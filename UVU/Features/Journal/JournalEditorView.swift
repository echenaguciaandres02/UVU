import SwiftUI
import SwiftData

/// Escribir o editar la entrada de un día: ánimo, texto libre, preguntas guía y etiquetas.
/// Hay una sola entrada por día: si ya existe, se edita esa.
struct JournalEditorView: View {
    let day: Date

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \JournalTag.name) private var allTags: [JournalTag]
    @AppStorage(JournalPrompts.storageKey) private var promptsRaw = JournalPrompts.encode(JournalPrompts.defaults)

    @State private var mood = 3
    @State private var text = ""
    @State private var answers: [AnswerDraft] = []
    @State private var tags: [String] = []
    @State private var newTag = ""
    @State private var existing: JournalEntry?
    @State private var didLoad = false
    @State private var confirmDelete = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: Space.xxs) {
                        Text(dayTitle)
                            .posterTitle(44, relativeTo: .title)
                        Text(PosterHeader.dateLine(day)).labelCaps(12, .semibold)
                    }
                    .listRowBackground(Color.clear)
                }

                Section {
                    MoodPicker(level: $mood)
                } header: {
                    Text("Ánimo").labelCaps()
                }
                .rowSurface()

                Section {
                    TextField("Escribe libremente…", text: $text, axis: .vertical)
                        .font(.editorial(22, relativeTo: .title3))
                        .lineLimit(5...20)
                        .foregroundStyle(.bone)
                        .accessibilityIdentifier("journal-text")
                } header: {
                    Text("Entrada").labelCaps()
                }
                .rowSurface()

                if !answers.isEmpty {
                    Section {
                        ForEach($answers) { $draft in
                            VStack(alignment: .leading, spacing: Space.xs) {
                                Text(draft.question)
                                    .font(.ui(14, .semibold, relativeTo: .subheadline))
                                    .foregroundStyle(.ash)
                                TextField("Opcional", text: $draft.answer, axis: .vertical)
                                    .lineLimit(1...8)
                                    .foregroundStyle(.bone)
                            }
                            .padding(.vertical, Space.xxs)
                        }
                    } header: {
                        Text("Preguntas guía").labelCaps()
                    } footer: {
                        Text("Opcionales. Cámbialas en Ajustes → Journal.").formFooter()
                    }
                    .rowSurface()
                }

                Section {
                    if !tags.isEmpty {
                        TagChips(tags: tags, onRemove: { tag in
                            withAnimation(Motion.quick) { tags.removeAll { JournalStore.sameTag($0, tag) } }
                        })
                    }
                    HStack(spacing: Space.s) {
                        Text("#")
                            .font(.ui(17, .black))
                            .foregroundStyle(.ash)
                        TextField("Agregar etiqueta", text: $newTag)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit { addTag(newTag) }
                    }
                    if !suggestions.isEmpty {
                        TagChips(tags: suggestions, onTap: { addTag($0) })
                    }
                } header: {
                    Text("Etiquetas").labelCaps()
                } footer: {
                    if !suggestions.isEmpty {
                        Text("Toca una sugerencia para agregarla.").formFooter()
                    }
                }
                .rowSurface()

                if existing != nil {
                    Section {
                        Button("Borrar entrada") { confirmDelete = true }
                            .buttonStyle(.uvuSecondary)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                }
            }
            .uvuForm()
            .navigationTitle(existing == nil ? "NUEVA ENTRADA" : "ENTRADA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .fontWeight(.semibold)
                }
            }
            .confirmationDialog("¿Borrar la entrada de este día?", isPresented: $confirmDelete,
                                titleVisibility: .visible) {
                Button("Borrar", role: .destructive) {
                    if let existing {
                        JournalStore.delete(existing, in: context)
                    }
                    dismiss()
                }
            } message: {
                Text("No se puede deshacer.")
            }
            .onAppear(perform: load)
        }
        .presentationBackground(Color.ink)
    }

    // MARK: - Datos

    private var dayTitle: String {
        if AppCalendar.calendar.isDateInToday(day) { return "Hoy." }
        if AppCalendar.calendar.isDateInYesterday(day) { return "Ayer." }
        return day.formatted(.dateTime.day().month(.abbreviated).locale(AppLocale.spanish))
            .replacingOccurrences(of: ".", with: "") + "."
    }

    /// Etiquetas ya usadas que aún no tiene esta entrada (filtradas por lo que se escribe).
    private var suggestions: [String] {
        let typed = JournalStore.normalizedTagName(newTag)
        return allTags.map(\.name)
            .filter { name in !tags.contains { JournalStore.sameTag($0, name) } }
            .filter { typed.isEmpty || $0.localizedStandardContains(typed) }
            .prefix(8)
            .map { $0 }
    }

    private func addTag(_ raw: String) {
        let name = JournalStore.normalizedTagName(raw)
        guard !name.isEmpty, !tags.contains(where: { JournalStore.sameTag($0, name) }) else {
            newTag = ""
            return
        }
        withAnimation(Motion.quick) { tags.append(name) }
        newTag = ""
        Haptics.tap()
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        let prompts = JournalPrompts.decode(promptsRaw)
        existing = JournalStore.entry(on: day, in: context)

        guard let entry = existing else {
            answers = prompts.map { AnswerDraft(question: $0, answer: "") }
            return
        }
        mood = entry.mood
        text = entry.text
        tags = entry.sortedTagNames
        // Respuestas guardadas + preguntas actuales que aún no tienen respuesta.
        var drafts = entry.sortedAnswers.map { AnswerDraft(question: $0.question, answer: $0.answer) }
        for prompt in prompts where !drafts.contains(where: { $0.question == prompt }) {
            drafts.append(AnswerDraft(question: prompt, answer: ""))
        }
        answers = drafts
    }

    private func save() {
        addTag(newTag)
        let entry = existing ?? JournalStore.entryOrNew(on: day, in: context)
        JournalStore.save(entry, text: text, mood: mood,
                          answers: answers.map { ($0.question, $0.answer) },
                          tagNames: tags, in: context)
        Haptics.success()
        dismiss()
    }
}

/// Respuesta a una pregunta guía, aún sin guardar.
struct AnswerDraft: Identifiable {
    let id = UUID()
    let question: String
    var answer: String
}
