import SwiftUI
import SwiftData

struct TodayView: View {
    @State private var showCalendar = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(greeting)
                            .font(.title2.bold())
                        Text(formattedDate)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    ContentUnavailableView(
                        "Tu día, en un vistazo",
                        systemImage: "sun.max",
                        description: Text("Aquí verás tus hábitos, tareas, recordatorios, el entreno del día y tu journal. Se completa en la fase 6.")
                    )
                }
            }
            .navigationTitle("Hoy")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel("Calendario")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
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
        case 5..<12: return "Buenos días"
        case 12..<19: return "Buenas tardes"
        default: return "Buenas noches"
        }
    }

    private var formattedDate: String {
        Date.now
            .formatted(.dateTime.weekday(.wide).day().month(.wide).locale(AppLocale.spanish))
            .capitalizedFirst
    }
}

#Preview {
    TodayView()
        .modelContainer(PreviewData.container)
}
