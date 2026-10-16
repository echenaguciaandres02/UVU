import SwiftUI

struct JournalHomeView: View {
    var body: some View {
        NavigationStack {
            ContentUnavailableView(
                "Tu journal",
                systemImage: "book.closed",
                description: Text("Entradas diarias, estado de ánimo, etiquetas y Face ID llegan en la fase 4.")
            )
            .navigationTitle("Journal")
        }
    }
}

#Preview {
    JournalHomeView()
}
