import SwiftUI
import SwiftData

/// Mis listas: crear, editar, ordenar y borrar.
struct TaskListsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \TaskList.sortOrder) private var lists: [TaskList]

    @State private var editingList: TaskList?
    @State private var showNewList = false
    @State private var listToDelete: TaskList?

    var body: some View {
        List {
            Section {
                ForEach(lists) { list in
                    NavigationLink(value: TasksRoute.list(list)) {
                        HStack(spacing: Space.s) {
                            SymbolBadge(symbol: list.symbol, colorHex: list.colorHex)
                            Text(list.name)
                                .font(.ui(16, .semibold))
                                .textCase(.uppercase)
                                .foregroundStyle(.bone)
                            Spacer()
                            Text("\(list.pendingCount)")
                                .font(.numeral(22, weight: .thin, relativeTo: .title3))
                                .monospacedDigit()
                                .foregroundStyle(.ash)
                        }
                    }
                    .rowSurface()
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            listToDelete = list
                        } label: {
                            Label("Borrar", systemImage: "trash")
                        }
                        Button {
                            editingList = list
                        } label: {
                            Label("Editar", systemImage: "pencil")
                        }
                        .tint(.graphite)
                    }
                }
                .onMove(perform: move)
            } footer: {
                Text("Desliza una lista a la izquierda para editarla o borrarla. Mantén pulsado y arrastra para ordenar.")
                    .formFooter()
            }
        }
        .screenBackground()
        .navigationTitle("LISTAS")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showNewList = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.bold)
                }
                .accessibilityLabel("Nueva lista")
            }
        }
        .sheet(isPresented: $showNewList) {
            ListFormView(list: nil)
        }
        .sheet(item: $editingList) { list in
            ListFormView(list: list)
        }
        .confirmationDialog(
            "¿Borrar la lista \"\(listToDelete?.name ?? "")\"?",
            isPresented: Binding(get: { listToDelete != nil }, set: { if !$0 { listToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Borrar lista y sus \(listToDelete?.tasks?.count ?? 0) tareas", role: .destructive) {
                if let list = listToDelete { delete(list) }
            }
        } message: {
            Text("No se puede deshacer.")
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = lists
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, list) in ordered.enumerated() {
            list.sortOrder = index
        }
        try? context.save()
    }

    private func delete(_ list: TaskList) {
        for task in list.tasks ?? [] {
            NotificationService.removeTaskReminders(for: task.id)
        }
        context.delete(list)
        try? context.save()
        listToDelete = nil
    }
}

/// Tareas de una lista: pendientes y, plegadas, las hechas.
struct ListTasksView: View {
    let list: TaskList

    @State private var editingTask: TaskItem?
    @State private var showNewTask = false
    @State private var showEditList = false
    @State private var showCompleted = false

    var body: some View {
        let all = list.tasks ?? []
        let pending = TaskGrouping.sortPending(all.filter { !$0.isCompleted })
        let done = all.filter(\.isCompleted).sorted { ($0.completedAt ?? .distantPast) > ($1.completedAt ?? .distantPast) }

        List {
            if pending.isEmpty {
                Section {
                    RedPoster(text: Quotes.empty, caption: "Toca + para agregar una tarea", minHeight: 180)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            } else {
                Section {
                    ForEach(pending) { task in
                        TaskRowView(task: task, showList: false) { editingTask = task }
                            .taskRowSurface(task.list)
                    }
                } header: {
                    Text("Pendientes · \(pending.count)").labelCaps()
                }
            }

            if !done.isEmpty {
                Section {
                    DisclosureGroup(isExpanded: $showCompleted.animation(Motion.quick)) {
                        ForEach(done) { task in
                            TaskRowView(task: task, showList: false) { editingTask = task }
                        }
                    } label: {
                        Text("Hechas · \(done.count)").labelCaps(12, .black, color: .bone)
                    }
                    .tint(.ash)
                    .rowSurface()
                }
            }
        }
        .screenBackground()
        .navigationTitle(list.name.uppercased())
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button("Editar") { showEditList = true }
                    .font(.ui(16, .semibold))
                Button {
                    showNewTask = true
                } label: {
                    Image(systemName: "plus")
                        .fontWeight(.bold)
                }
                .accessibilityLabel("Nueva tarea")
            }
        }
        .sheet(isPresented: $showNewTask) {
            TaskFormView(task: nil, defaultList: list)
        }
        .sheet(item: $editingTask) { task in
            TaskFormView(task: task)
        }
        .sheet(isPresented: $showEditList) {
            ListFormView(list: list)
        }
    }
}

/// Crear o editar una lista: nombre, ícono y color.
struct ListFormView: View {
    let list: TaskList?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \TaskList.sortOrder) private var lists: [TaskList]

    @State private var name = ""
    @State private var symbol = "list.bullet"
    @State private var colorHex = "007AFF"
    @State private var didLoad = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Nombre de la lista", text: $name)
                        .font(.ui(20, .semibold, relativeTo: .title3))
                }
                .rowSurface()

                Section {
                    NavigationLink {
                        SymbolPickerView(selection: $symbol, colorHex: colorHex)
                    } label: {
                        HStack {
                            Text("Ícono")
                            Spacer()
                            SymbolBadge(symbol: symbol, colorHex: colorHex, size: 32)
                        }
                    }
                    ColorPaletteView(selection: $colorHex)
                } header: {
                    Text("Apariencia").labelCaps()
                }
                .rowSurface()
            }
            .uvuForm()
            .navigationTitle(list == nil ? "NUEVA LISTA" : "EDITAR LISTA")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onAppear {
                guard !didLoad else { return }
                didLoad = true
                if let list {
                    name = list.name
                    symbol = list.symbol
                    colorHex = list.colorHex
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.ink)
    }

    private func save() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let list {
            list.name = trimmed
            list.symbol = symbol
            list.colorHex = colorHex
        } else {
            let nextOrder = (lists.map(\.sortOrder).max() ?? -1) + 1
            context.insert(TaskList(name: trimmed, symbol: symbol, colorHex: colorHex, sortOrder: nextOrder))
        }
        try? context.save()
        // El nombre de la lista aparece en las notificaciones.
        Task { await NotificationService.rescheduleTasks(context: context) }
        dismiss()
    }
}
