import SwiftUI

/// Cuadrícula mensual (lunes a domingo) con flechas para cambiar de mes.
/// El contenido de cada día lo decide quien la usa (hábitos, journal, calendario unificado).
struct MonthCalendarView<DayContent: View>: View {
    @Binding var month: Date
    private let dayContent: (Date) -> DayContent

    init(month: Binding<Date>, @ViewBuilder dayContent: @escaping (Date) -> DayContent) {
        self._month = month
        self.dayContent = dayContent
    }

    private var calendar: Calendar { AppCalendar.calendar }
    private let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Mes anterior")
                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .frame(width: 36, height: 36)
                }
                .accessibilityLabel("Mes siguiente")
            }
            .buttonStyle(.borderless)

            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(AppCalendar.orderedWeekdays, id: \.self) { weekday in
                    Text(AppCalendar.veryShortWeekdayName(weekday))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                }
                ForEach(0..<leadingBlanks, id: \.self) { index in
                    Color.clear
                        .frame(height: 1)
                        .id("blank-\(index)")
                }
                ForEach(days, id: \.self) { day in
                    dayContent(day)
                }
            }
        }
    }

    private var title: String {
        month.formatted(.dateTime.month(.wide).year().locale(AppLocale.spanish)).capitalizedFirst
    }

    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: month) ?? DateInterval(start: month, duration: 86_400)
    }

    private var days: [Date] {
        var result: [Date] = []
        var day = monthInterval.start
        while day < monthInterval.end {
            result.append(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    private var leadingBlanks: Int {
        let weekday = calendar.component(.weekday, from: monthInterval.start)
        return (weekday - calendar.firstWeekday + 7) % 7
    }

    private func shiftMonth(by value: Int) {
        if let newMonth = calendar.date(byAdding: .month, value: value, to: month) {
            month = newMonth
        }
    }
}

/// Un día del calendario: número dentro de un círculo coloreado según su estado.
struct CalendarDayCell: View {
    let date: Date
    var fill: Color?
    var textColor: Color = .primary
    var accessibilityStatus: String = ""

    var body: some View {
        let isToday = AppCalendar.calendar.isDateInToday(date)
        Text("\(AppCalendar.calendar.component(.day, from: date))")
            .font(.callout.weight(isToday ? .bold : .regular))
            .monospacedDigit()
            .foregroundStyle(fill == nil ? Color.primary : textColor)
            .frame(width: 36, height: 36)
            .background {
                Circle().fill(fill ?? Color.clear)
            }
            .overlay {
                if isToday {
                    Circle()
                        .strokeBorder(Color.accentColor, lineWidth: 2)
                        .padding(-3)
                }
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let dateText = date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(AppLocale.spanish))
        return accessibilityStatus.isEmpty ? dateText : "\(dateText), \(accessibilityStatus)"
    }
}

extension HabitDayStatus {
    var fillColor: Color? {
        switch self {
        case .completed: return .green
        case .partial: return .yellow
        case .failed: return .red
        case .notApplicable: return Color(.systemGray4)
        case .pending, .future: return nil
        }
    }

    var textColor: Color {
        switch self {
        case .completed, .failed: return .white
        case .partial: return .black
        default: return .primary
        }
    }

    var title: String {
        switch self {
        case .completed: return "Cumplido"
        case .partial: return "Parcial"
        case .failed: return "Fallado"
        case .notApplicable: return "No aplicaba"
        case .pending: return "Pendiente"
        case .future: return ""
        }
    }
}

/// Leyenda de colores de los calendarios de hábitos.
struct HabitStatusLegend: View {
    private let items: [HabitDayStatus] = [.completed, .partial, .failed, .notApplicable]

    var body: some View {
        HStack(spacing: 14) {
            ForEach(items, id: \.title) { status in
                HStack(spacing: 4) {
                    Circle()
                        .fill(status.fillColor ?? .clear)
                        .frame(width: 10, height: 10)
                    Text(status.title)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity)
    }
}

/// Fecha envuelta para usarla con `.sheet(item:)`.
struct SelectedDay: Identifiable {
    let date: Date
    var id: Date { date }
}

#Preview {
    MonthCalendarView(month: .constant(.now)) { day in
        CalendarDayCell(date: day, fill: day < .now ? .green : nil, textColor: .white)
    }
    .padding()
}
