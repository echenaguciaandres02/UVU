import SwiftUI
import SwiftData

struct TasksHomeView: View {
    @Query(sort: \TaskList.sortOrder) private var lists: [TaskList]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(lists) { list in
                        HStack(spacing: 12) {
                            SymbolBadge(symbol: list.symbol, colorHex: list.colorHex)
                            Text(list.name)
                            Spacer()
                            Text("\(list.pendingCount)")
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Mis listas")
                } footer: {
                    Text("Tareas, recordatorios y notificaciones llegan en la fase 3.")
                }
            }
            .navigationTitle("Tareas")
        }
    }
}

#Preview {
    TasksHomeView()
        .modelContainer(PreviewData.container)
}
