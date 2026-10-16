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

    var body: some View {
        VStack(spacing: Space.s) {
            HStack {
                Text(title)
                    .font(.display(26, relativeTo: .title2))
                    .textCase(.uppercase)
                    .foregroundStyle(.bone)
                Spacer()
                Button {
                    shiftMonth(by: -1)
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Mes anterior")
                Button {
                    shiftMonth(by: 1)
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 15, weight: .bold))
                        .frame(width: 40, height: 40)
                }
                .accessibilityLabel("Mes siguiente")
            }
            .buttonStyle(.borderless)
            .foregroundStyle(.bone)

            // Cuadrícula fija (no perezosa): dentro de una List, una LazyVGrid puede entrar en un
            // ciclo infinito de cálculo de alturas y cerrar la app.
            VStack(spacing: Space.xxs) {
                HStack(spacing: Space.xxs) {
                    ForEach(AppCalendar.orderedWeekdays, id: \.self) { weekday in
                        Text(AppCalendar.veryShortWeekdayName(weekday))
                            .labelCaps(11, .semibold)
                            .frame(maxWidth: .infinity)
                    }
                }
                .padding(.bottom, Space.xxs)

                ForEach(Array(weeks.enumerated()), id: \.offset) { _, week in
                    HStack(spacing: Space.xxs) {
                        ForEach(0..<7, id: \.self) { index in
                            if let day = week[index] {
                                dayContent(day)
                                    .frame(maxWidth: .infinity)
                            } else {
                                Color.clear
                                    .aspectRatio(1, contentMode: .fit)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                    }
                }
            }
        }
    }

    /// Semanas del mes, de lunes a domingo; `nil` en los huecos antes del día 1 y después del último.
    private var weeks: [[Date?]] {
        var cells: [Date?] = Array(repeating: nil, count: leadingBlanks) + days.map { Optional($0) }
        while cells.count % 7 != 0 { cells.append(nil) }
        return stride(from: 0, to: cells.count, by: 7).map { Array(cells[$0..<$0 + 7]) }
    }

    private var title: String {
        month.formatted(.dateTime.month(.wide).year().locale(AppLocale.spanish))
    }

    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: month) ?? DateInterval(start: month, duration: 86_400)
    }

    private var days: [Date] {
        let interval = monthInterval
        var result: [Date] = []
        var day = interval.start
        while day < interval.end {
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
            withAnimation(Motion.quick) { month = newMonth }
        }
    }
}

// MARK: - Heatmap

/// Cuadro de estado con la codificación DISCIPLINE:
/// completo = `signal` lleno · parcial = `signalDeep` · fallado = `carbon` tachado ·
/// no aplicaba = contorno punteado · pendiente/futuro = vacío.
struct StatusSwatch: View {
    let status: HabitDayStatus

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.sharp, style: .continuous)
        ZStack {
            switch status {
            case .completed:
                shape.fill(.signal)
            case .partial:
                shape.fill(.signalDeep)
            case .failed:
                shape.fill(.carbon)
                SlashShape()
                    .stroke(Color.ash.opacity(0.7), lineWidth: 1.5)
                    .clipShape(shape)
            case .notApplicable:
                shape.strokeBorder(.graphite, style: StrokeStyle(lineWidth: 1, dash: [2, 2]))
            case .pending:
                shape.strokeBorder(.graphite, lineWidth: Stroke.hairline)
            case .future:
                Color.clear
            }
        }
    }
}

/// Diagonal de abajo-izquierda a arriba-derecha (día fallado).
struct SlashShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        return path
    }
}

/// Un día del calendario de hábitos: cuadro de estado con el número encima.
struct CalendarDayCell: View {
    let date: Date
    let status: HabitDayStatus
    var isSelected = false

    var body: some View {
        let isToday = AppCalendar.calendar.isDateInToday(date)
        StatusSwatch(status: status)
            .aspectRatio(1, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .overlay {
                Text("\(AppCalendar.calendar.component(.day, from: date))")
                    .font(.ui(15, isToday ? .black : .semibold, relativeTo: .callout))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .foregroundStyle(status.numberColor)
                    .padding(2)
            }
            .overlay {
                if isToday || isSelected {
                    RoundedRectangle(cornerRadius: Radius.sharp, style: .continuous)
                        .strokeBorder(isSelected ? Color.bone : .ash, lineWidth: isSelected ? 2 : 1.5)
                        .padding(-3)
                }
            }
            .padding(3)
            .contentShape(Rectangle())
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(accessibilityText(isToday: isToday))
    }

    private func accessibilityText(isToday: Bool) -> String {
        var text = date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(AppLocale.spanish))
        if isToday { text = "Hoy, " + text }
        let statusText = status.title
        return statusText.isEmpty ? text : "\(text), \(statusText)"
    }
}

extension HabitDayStatus {
    /// Color del número del día según el fondo del cuadro.
    var numberColor: Color {
        switch self {
        case .completed: return .ink
        case .partial, .failed, .pending: return .bone
        case .notApplicable, .future: return .ash
        }
    }

    var title: String {
        switch self {
        case .completed: return "Completo"
        case .partial: return "Parcial"
        case .failed: return "Fallado"
        case .notApplicable: return "No aplicaba"
        case .pending: return "Pendiente"
        case .future: return ""
        }
    }
}

/// Leyenda de los calendarios de hábitos.
struct HabitStatusLegend: View {
    private let items: [HabitDayStatus] = [.completed, .partial, .failed, .notApplicable]

    var body: some View {
        Grid(alignment: .leading, horizontalSpacing: Space.m, verticalSpacing: Space.xs) {
            GridRow {
                item(items[0])
                item(items[1])
            }
            GridRow {
                item(items[2])
                item(items[3])
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func item(_ status: HabitDayStatus) -> some View {
        HStack(spacing: Space.xs) {
            StatusSwatch(status: status)
                .frame(width: 14, height: 14)
            Text(status.title)
                .labelCaps(10, .semibold)
                .fixedSize()
        }
    }
}

/// Fecha envuelta para usarla con `.sheet(item:)`.
struct SelectedDay: Identifiable {
    let date: Date
    var id: Date { date }
}

#Preview {
    MonthCalendarView(month: .constant(.now)) { day in
        let index = AppCalendar.calendar.component(.day, from: day)
        let statuses: [HabitDayStatus] = [.completed, .completed, .partial, .failed, .notApplicable, .completed]
        CalendarDayCell(date: day, status: day > .now ? .future : statuses[index % statuses.count])
    }
    .padding()
    .background(Color.ink)
}
