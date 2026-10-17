import SwiftUI
import SwiftData

struct TodayView: View {
    @State private var showCalendar = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(greeting)
                            .labelCaps(13, .semibold, color: .ash)
                        PosterHeader(title: "Hoy.", subtitle: PosterHeader.dateLine(), size: 104)
                    }

                    RedPoster(text: Quotes.ofTheDay(), caption: "Frase del día", topInset: 64)
                        .overlay(alignment: .topTrailing) {
                            TapeLabel(text: "DO.")
                                .padding(Space.m)
                        }

                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text("Tu día en un vistazo")
                            .labelCaps(12, .black, color: .bone)
                        Text("Hábitos, tareas, recordatorios, el entreno y tu journal. Llega en la fase 6.")
                            .font(.uiCallout)
                            .foregroundStyle(.ash)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface()
                }
                .padding(.horizontal, Space.m)
                .padding(.bottom, Space.xl)
            }
            .background(Color.ink.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                            .fontWeight(.bold)
                    }
                    .accessibilityLabel("Calendario")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .fontWeight(.bold)
                    }
                    .accessibilityLabel("Ajustes")
                }
            }
            .sheet(isPresented: $showCalendar) {
                UnifiedCalendarView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
        }
    }

    private var greeting: String {
        switch AppCalendar.calendar.component(.hour, from: .now) {
        case 4..<12: return "Buenos días"
        case 12..<19: return "Buenas tardes"
        default: return "Buenas noches"
        }
    }
}

#Preview {
    TodayView()
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.dark)
}
