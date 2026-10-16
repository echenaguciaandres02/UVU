import SwiftUI
import SwiftData

/// Crear (`task == nil`) o editar una tarea: título, notas, lista, fecha/hora, aviso,
/// repetición, prioridad y subtareas.
struct TaskFormView: View {
    let task: TaskItem?
    var defaultDue: Date?
    var defaultList: TaskList?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskList.sortOrder) private var lists: [TaskList]

    @State private var title = ""
    @State private var notes = ""
    @State private var listID: UUID?
    @State private var hasDate = false
    @State private var date = Date.now
    @State private var hasTime = false
    @State private var time = Calendar.current.date(bySettingHour: 18, minute: 0, second: 0, of: .now) ?? .now
    @State private var reminderEnabled = true
    @State private var reminderOffset: ReminderOffset = .atTime
    @State private var recurrence: TaskRecurrence = .none
    @State private var priority: TaskItemPriority = .none
    @State private var subtasks: [SubtaskDraft] = []
    @State private var newSubtask = ""
    @State private var didLoad = false
    @State private var confirmDelete = false
    @FocusState private var titleFocused: Bool

    init(task: TaskItem?, defaultDue: Date? = nil, defaultList: TaskList? = nil) {
        self.task = task
        self.defaultDue = defaultDue
        self.defaultList = defaultList
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Qué hay que hacer", text: $title, axis: .vertical)
                        .font(.ui(20, .semibold, relativeTo: .title3))
                        .focused($titleFocused)
                        .accessibilityIdentifier("task-title")
                    TextField("Notas", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                        .foregroundStyle(.bone)
                }
                .rowSurface()

                Section {
                    Picker("Lista", selection: $listID) {
                        ForEach(lists) { list in
                            Text(list.name).tag(Optional(list.id))
                        }
                    }
                    Picker("Prioridad", selection: $priority) {
                        ForEach(TaskItemPriority.allCases) { priority in
                            Text(priority.title).tag(priority)
                        }
                    }
                } header: {
                    Text("Organizar").labelCaps()
                }
                .rowSurface()

                Section {
                    Toggle("Fecha límite", isOn: $hasDate.animation(Motion.quick))
                        .tint(.signal)
                    if hasDate {
                        DatePicker("Día", selection: $date, displayedComponents: .date)
                        Toggle("Hora", isOn: $hasTime.animation(Motion.quick))
                            .tint(.signal)
                        if hasTime {
                            DatePicker("A las", selection: $time, displayedComponents: .hourAndMinute)
                        }
                        Picker("Repetir", selection: $recurrence) {
                            ForEach(TaskRecurrence.allCases) { recurrence in
                                Text(recurrence.title).tag(recurrence)
                            }
                        }
                    }
                } header: {
                    Text("Fecha").labelCaps()
                }
                .rowSurface()

                if hasDate {
                    Section {
                        Toggle("Avisarme", isOn: $reminderEnabled.animation(Motion.quick))
                            .tint(.signal)
                        if reminderEnabled {
                            Picker("Cuándo", selection: $reminderOffset) {
                                ForEach(ReminderOffset.allCases) { offset in
                                    Text(offset.title).tag(offset)
                                }
                            }
                        }
                    } header: {
                        Text("Aviso").labelCaps()
                    } footer: {
                        Text(reminderFooter).formFooter()
                    }
                    .rowSurface()
                }

                Section {
                    ForEach($subtasks) { $subtask in
                        HStack(spacing: Space.s) {
                            Button {
                                subtask.isDone.toggle()
                                if subtask.isDone { Haptics.stamp() } else { Haptics.tap() }
                            } label: {
                                HabitCheckbox(progress: subtask.isDone ? 1 : 0, size: 20)
                            }
                            .buttonStyle(.borderless)
                            .accessibilityLabel(subtask.isDone ? "Desmarcar subtarea" : "Marcar subtarea")
                            TextField("Subtarea", text: $subtask.title)
                                .foregroundStyle(subtask.isDone ? Color.ash : .bone)
                        }
                    }
                    .onDelete { subtasks.remove(atOffsets: $0) }
                    .onMove { subtasks.move(fromOffsets: $0, toOffset: $1) }

                    HStack(spacing: Space.s) {
                        Image(systemName: "plus")
                            .fontWeight(.bold)
                            .foregroundStyle(.ash)
                            .frame(width: 20)
                        TextField("Agregar subtarea", text: $newSubtask)
                            .submitLabel(.next)
                            .onSubmit(addSubtask)
                    }
                } header: {
                    Text("Subtareas").labelCaps()
                }
                .rowSurface()

                if let task {
                    Section {
                        Button(task.isCompleted ? "Reabrir" : "Completar") {
                            toggleCompletion(task)
                        }
                        .buttonStyle(.uvuPrimary)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: Space.xs, trailing: 0))

                        Button("Borrar tarea") { confirmDelete = true }
                            .buttonStyle(.uvuSecondary)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets())
                    }
                }
            }
            .uvuForm()
            .navigationTitle(task == nil ? "NUEVA TAREA" : "TAREA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .fontWeight(.semibold)
                        .disabled(trimmedTitle.isEmpty)
                }
            }
            .confirmationDialog("¿Borrar esta tarea?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Borrar", role: .destructive) {
                    if let task {
                        TaskActions.delete(task, in: context)
                        dismiss()
                    }
                }
            } message: {
                Text("Se borra con sus subtareas. No se puede deshacer.")
            }
            .onAppear(perform: load)
        }
        .presentationBackground(Color.ink)
    }

    // MARK: - Datos

    private var trimmedTitle: String {
        title.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var reminderFooter: String {
        guard reminderEnabled else { return "Sin notificación. La tarea igual aparece en Hoy y Próximos." }
        if hasTime { return "Recibirás una notificación con los botones Completar y Posponer 1 hora." }
        return "Sin hora: el aviso usa la hora de Ajustes (\(ReminderTime.format(TaskSchedule.defaultReminderMinutes)))."
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let task else {
            listID = defaultList?.id ?? lists.first?.id
            if let defaultDue {
                hasDate = true
                date = defaultDue
            }
            titleFocused = true
            return
        }
        title = task.title
        notes = task.notes
        listID = task.list?.id
        if let due = task.dueDate {
            hasDate = true
            date = due
            hasTime = task.hasTime
            if task.hasTime { time = due }
        }
        reminderEnabled = task.reminderEnabled
        reminderOffset = ReminderOffset(rawValue: task.reminderOffsetMinutes) ?? .atTime
        recurrence = task.recurrence
        priority = task.priority
        subtasks = task.sortedSubtasks.map { SubtaskDraft(existingID: $0.id, title: $0.title, isDone: $0.isDone) }
    }

    private func addSubtask() {
        let text = newSubtask.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        subtasks.append(SubtaskDraft(existingID: nil, title: text, isDone: false))
        newSubtask = ""
    }

    private var resolvedDueDate: Date? {
        guard hasDate else { return nil }
        let day = AppCalendar.startOfDay(date)
        guard hasTime else { return day }
        let parts = AppCalendar.calendar.dateComponents([.hour, .minute], from: time)
        return AppCalendar.calendar.date(bySettingHour: parts.hour ?? 0, minute: parts.minute ?? 0, second: 0, of: day)
    }

    private func save() {
        addSubtask()
        let target: TaskItem
        if let task {
            target = task
        } else {
            target = TaskItem(title: trimmedTitle)
            context.insert(target)
        }

        target.title = trimmedTitle
        target.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        target.dueDate = resolvedDueDate
        target.hasTime = hasDate && hasTime
        target.reminderEnabled = reminderEnabled
        target.reminderOffsetMinutes = reminderOffset.rawValue
        target.recurrence = hasDate ? recurrence : .none
        target.priority = priority
        target.list = lists.first { $0.id == listID }

        syncSubtasks(of: target)
        try? context.save()
        Task { await NotificationService.scheduleTaskReminder(for: target) }
        dismiss()
    }

    private func syncSubtasks(of task: TaskItem) {
        let drafts = subtasks.filter { !$0.title.trimmingCharacters(in: .whitespaces).isEmpty }
        let keptIDs = Set(drafts.compactMap(\.existingID))
        for existing in task.subtasks ?? [] where !keptIDs.contains(existing.id) {
            context.delete(existing)
        }
        for (index, draft) in drafts.enumerated() {
            if let id = draft.existingID, let existing = task.subtasks?.first(where: { $0.id == id }) {
                existing.title = draft.title
                existing.isDone = draft.isDone
                existing.order = index
            } else {
                let subtask = Subtask(title: draft.title, order: index)
                subtask.isDone = draft.isDone
                context.insert(subtask)
                subtask.task = task
            }
        }
    }

    private func toggleCompletion(_ task: TaskItem) {
        save()
        if task.isCompleted {
            TaskActions.reopen(task, in: context)
        } else {
            TaskActions.complete(task, in: context)
            Haptics.stamp()
        }
    }
}

/// Subtarea en edición (aún sin guardar).
struct SubtaskDraft: Identifiable {
    let id = UUID()
    var existingID: UUID?
    var title: String
    var isDone: Bool
}
