import SwiftUI

struct JournalHomeView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    QuoteCard(text: "Una gran parte de quien soy es quien ya no soy.")
                    RedPoster(text: Quotes.empty,
                              caption: "Entradas, ánimo, etiquetas y Face ID llegan en la fase 4",
                              minHeight: 200)
                }
                .padding(Space.m)
            }
            .background(Color.ink.ignoresSafeArea())
            .navigationTitle("JOURNAL")
        }
    }
}

#Preview {
    JournalHomeView()
        .preferredColorScheme(.dark)
}
