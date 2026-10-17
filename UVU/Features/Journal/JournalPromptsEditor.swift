import SwiftUI

/// Editar las preguntas guía del journal: agregar, borrar y ordenar.
struct JournalPromptsEditor: View {
    @AppStorage(JournalPrompts.storageKey) private var promptsRaw = JournalPrompts.encode(JournalPrompts.defaults)
    @State private var prompts: [PromptDraft] = []
    @State private var newPrompt = ""
    @State private var didLoad = false

    var body: some View {
        List {
            Section {
                ForEach($prompts) { $prompt in
                    TextField("Pregunta", text: $prompt.text, axis: .vertical)
                        .onSubmit(persist)
                }
                .onDelete { prompts.remove(atOffsets: $0); persist() }
                .onMove { prompts.move(fromOffsets: $0, toOffset: $1); persist() }

                HStack(spacing: Space.s) {
                    Image(systemName: "plus")
                        .fontWeight(.bold)
                        .foregroundStyle(.ash)
                    TextField("Nueva pregunta", text: $newPrompt)
                        .submitLabel(.done)
                        .onSubmit(add)
                }
            } footer: {
                Text("Aparecen al escribir cada entrada. Responderlas es opcional. Desliza para borrar.")
                    .formFooter()
            }
            .rowSurface()

            Section {
                Button("Restaurar preguntas originales") {
                    prompts = JournalPrompts.defaults.map { PromptDraft(text: $0) }
                    persist()
                }
                .buttonStyle(.uvuSecondary)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .uvuForm()
        .navigationTitle("PREGUNTAS")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .onAppear {
            guard !didLoad else { return }
            didLoad = true
            prompts = JournalPrompts.decode(promptsRaw).map { PromptDraft(text: $0) }
        }
        .onDisappear(perform: persist)
    }

    private func add() {
        let text = newPrompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        prompts.append(PromptDraft(text: text))
        newPrompt = ""
        persist()
    }

    private func persist() {
        let list = prompts.map { $0.text.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        promptsRaw = JournalPrompts.encode(list)
    }
}

private struct PromptDraft: Identifiable {
    let id = UUID()
    var text: String
}
