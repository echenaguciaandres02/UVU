import SwiftUI
import SwiftData

struct TasksHomeView: View {
    @Query(sort: \TaskList.sortOrder) private var lists: [TaskList]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(lists) { list in
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
                        .rowSurface()
                    }
                } header: {
                    Text("Mis listas").labelCaps()
                }

                Section {
                    RedPoster(text: Quotes.empty, caption: "Tareas y recordatorios llegan en la fase 3", minHeight: 180)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets())
                }
            }
            .screenBackground()
            .navigationTitle("TAREAS")
        }
    }
}

#Preview {
    TasksHomeView()
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.dark)
}
