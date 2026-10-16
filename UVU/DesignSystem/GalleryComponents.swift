#if DEBUG
import SwiftUI

/// Sección de componentes de `DesignSystemGallery`.
struct GalleryComponents: View {
    @State private var month = Date.now
    @State private var checked = false

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xl) {
            block("PosterHeader") {
                PosterHeader(title: "Hoy.", subtitle: PosterHeader.dateLine())
            }

            block("RedPoster + TapeLabel") {
                RedPoster(text: "¿Quién eres cuando nadie mira?", caption: "Frase del día")
                    .overlay(alignment: .topTrailing) {
                        TapeLabel(text: "DO.").padding(Space.m)
                    }
            }

            block("HabitCheckbox · QuantityBar") {
                HStack(spacing: Space.l) {
                    HabitCheckbox(progress: 0)
                    HabitCheckbox(progress: 0.35)
                    HabitCheckbox(progress: 0.7)
                    HabitCheckbox(progress: 1)
                    Button {
                        checked.toggle()
                    } label: {
                        HabitCheckbox(progress: checked ? 1 : 0)
                    }
                    .buttonStyle(.plain)
                }
                QuantityBar(progress: 0.6)
            }

            block("StreakCounter") {
                HStack(alignment: .top, spacing: Space.xl) {
                    StreakCounter(value: 12, unit: "días")
                    StreakCounter(value: 34, unit: "días", isRecord: true)
                }
            }

            block("UVUButton") {
                Button("Empezar") {}.buttonStyle(.uvuPrimary)
                Button("Editar") {}.buttonStyle(.uvuSecondary)
            }

            block("QuoteCard") {
                QuoteCard(text: "Empieza donde estás.")
            }

            block("CalendarHeatmap") {
                MonthCalendarView(month: $month) { day in
                    CalendarDayCell(date: day, status: sampleStatus(day))
                }
                HabitStatusLegend()
            }

            block("Íconos de hábito (apagados)") {
                HStack(spacing: Space.s) {
                    SymbolBadge(symbol: "drop.fill", colorHex: "007AFF", size: 40)
                    SymbolBadge(symbol: "sun.max.fill", colorHex: "FFCC00", size: 40)
                    SymbolBadge(symbol: "book.fill", colorHex: "34C759", size: 40)
                    SymbolBadge(symbol: "graduationcap.fill", colorHex: "5856D6", size: 40)
                    SymbolBadge(symbol: "fork.knife", colorHex: "FF2D55", size: 40)
                }
            }
        }
    }

    private func sampleStatus(_ day: Date) -> HabitDayStatus {
        let today = AppCalendar.startOfDay(.now)
        if day > today { return .future }
        if AppCalendar.calendar.isDateInToday(day) { return .pending }
        let pattern: [HabitDayStatus] = [.completed, .completed, .partial, .completed, .failed,
                                         .completed, .notApplicable, .completed]
        return pattern[AppCalendar.calendar.component(.day, from: day) % pattern.count]
    }

    private func block<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Text(title).labelCaps(12, .black, color: .bone)
            Rectangle().fill(.graphite).frame(height: Stroke.hairline)
            content()
        }
    }
}
#endif
