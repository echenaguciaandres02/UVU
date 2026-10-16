import SwiftUI
import SwiftData

struct HabitsHomeView: View {
    @Query(filter: #Predicate<Habit> { $0.isArchived == false }, sort: \Habit.sortOrder)
    private var habits: [Habit]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(habits) { habit in
                        HStack(spacing: 12) {
                            SymbolBadge(symbol: habit.symbol, colorHex: habit.colorHex)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(habit.name)
                                Text("\(habit.frequencyDescription) · \(habit.goalDescription)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } footer: {
                    Text("Crear, editar, marcar y ver estadísticas llega en la fase 2.")
                }
            }
            .navigationTitle("Hábitos")
            .overlay {
                if habits.isEmpty {
                    ContentUnavailableView("Sin hábitos", systemImage: "checkmark.circle")
                }
            }
        }
    }
}

#Preview {
    HabitsHomeView()
        .modelContainer(PreviewData.container)
}
