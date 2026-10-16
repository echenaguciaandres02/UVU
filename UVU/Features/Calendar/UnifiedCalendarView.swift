import SwiftUI

struct UnifiedCalendarView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Calendario",
                systemImage: "calendar",
                description: Text("Hábitos, entrenos, tareas y journal de cada día. Se completa en la fase 6.")
            )
            .navigationTitle("Calendario")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    UnifiedCalendarView()
}
