import SwiftUI
import SwiftData

/// Arrastrar para cambiar el orden de los hábitos.
struct ReorderHabitsView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Habit> { $0.isArchived == false }, sort: \Habit.sortOrder)
    private var habits: [Habit]

    var body: some View {
        NavigationStack {
            List {
                ForEach(habits) { habit in
                    HStack(spacing: Space.s) {
                        SymbolBadge(symbol: habit.symbol, colorHex: habit.colorHex)
                        Text(habit.name)
                            .font(.ui(16, .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(.bone)
                    }
                    .rowSurface()
                }
                .onMove(perform: move)
            }
            .screenBackground()
            .environment(\.editMode, .constant(.active))
            .navigationTitle("ORDENAR")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        var ordered = habits
        ordered.move(fromOffsets: source, toOffset: destination)
        for (index, habit) in ordered.enumerated() {
            habit.sortOrder = index
        }
        try? context.save()
    }
}

/// Hábitos archivados: restaurar o eliminar definitivamente.
struct ArchivedHabitsView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Habit> { $0.isArchived == true }, sort: \Habit.name)
    private var archived: [Habit]
    @Query(filter: #Predicate<Habit> { $0.isArchived == false })
    private var active: [Habit]

    @State private var habitToDelete: Habit?

    var body: some View {
        List {
            ForEach(archived) { habit in
                HStack(spacing: Space.s) {
                    SymbolBadge(symbol: habit.symbol, colorHex: habit.colorHex)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(habit.name)
                            .font(.ui(16, .semibold))
                            .textCase(.uppercase)
                            .foregroundStyle(.bone)
                        Text("\(habit.entries?.count ?? 0) registros")
                            .labelCaps(11, .semibold)
                    }
                }
                .rowSurface()
                .swipeActions(edge: .trailing) {
                    Button("Eliminar", role: .destructive) { habitToDelete = habit }
                }
                .swipeActions(edge: .leading) {
                    Button("Restaurar") { restore(habit) }
                        .tint(.graphite)
                }
                .contextMenu {
                    Button {
                        restore(habit)
                    } label: {
                        Label("Restaurar", systemImage: "arrow.uturn.backward")
                    }
                    Button(role: .destructive) {
                        habitToDelete = habit
                    } label: {
                        Label("Eliminar", systemImage: "trash")
                    }
                }
            }
        }
        .screenBackground()
        .navigationTitle("ARCHIVADOS")
        .overlay {
            if archived.isEmpty {
                RedPoster(text: Quotes.empty, caption: "Aquí van los hábitos que archives")
                    .padding(Space.m)
            }
        }
        .confirmationDialog(
            "¿Eliminar \"\(habitToDelete?.name ?? "")\"?",
            isPresented: Binding(get: { habitToDelete != nil }, set: { if !$0 { habitToDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Eliminar con todo su historial", role: .destructive) {
                if let habit = habitToDelete { delete(habit) }
            }
        } message: {
            Text("Esta acción no se puede deshacer.")
        }
    }

    private func restore(_ habit: Habit) {
        habit.isArchived = false
        habit.sortOrder = (active.map(\.sortOrder).max() ?? -1) + 1
        try? context.save()
        Task { await NotificationService.scheduleHabitReminders(for: habit) }
    }

    private func delete(_ habit: Habit) {
        let id = habit.id
        Task { await NotificationService.removeHabitReminders(for: id) }
        context.delete(habit)
        try? context.save()
        habitToDelete = nil
    }
}
