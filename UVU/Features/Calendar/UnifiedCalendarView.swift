import SwiftUI

struct UnifiedCalendarView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    PosterHeader(title: "Calendario.", subtitle: "Todo tu mes en un lugar", size: 56)
                    RedPoster(text: Quotes.empty,
                              caption: "Hábitos, entrenos, tareas y journal por día: fase 6",
                              minHeight: 200)
                }
                .padding(Space.m)
            }
            .background(Color.ink.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .presentationBackground(Color.ink)
    }
}

#Preview {
    UnifiedCalendarView()
        .preferredColorScheme(.dark)
}
