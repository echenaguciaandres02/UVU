import SwiftUI
import SwiftData

/// Calendario general: el color de cada día resume todos los hábitos activos.
/// Al tocar un día, debajo se despliegan los íconos de lo cumplido y lo fallado.
struct HabitsCalendarView: View {
    @Query(filter: #Predicate<Habit> { $0.isArchived == false }, sort: \Habit.sortOrder)
    private var habits: [Habit]

    @State private var month = Date.now
    @State private var selectedDay = AppCalendar.startOfDay(.now)
    @State private var editingDay: SelectedDay?

    var body: some View {
        let evaluators = habits.map { HabitEvaluator(habit: $0) }

        List {
            Section {
                MonthCalendarView(month: $month) { day in
                    let status = HabitSummary.combinedStatus(evaluators, on: day)
                    let isSelected = AppCalendar.calendar.isDate(day, inSameDayAs: selectedDay)
                    Button {
                        withAnimation(Motion.quick) { selectedDay = day }
                        Haptics.tap()
                    } label: {
                        CalendarDayCell(date: day, status: status, isSelected: isSelected)
                    }
                    .buttonStyle(.borderless)
                    .disabled(status == .future)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
                .padding(.vertical, Space.xs)
                HabitStatusLegend()
                    .padding(.bottom, Space.xs)
            } footer: {
                Text("Rojo: todos cumplidos. Rojo oscuro: algunos. Tachado: ninguno.")
                    .formFooter()
            }
            .rowSurface()

            DaySummarySection(day: selectedDay, habits: habits) {
                editingDay = SelectedDay(date: selectedDay)
            }
            .rowSurface()
        }
        .screenBackground()
        .navigationTitle("CALENDARIO")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editingDay) { selection in
            DayHabitsSheet(day: selection.date)
        }
    }
}

/// Resumen de un día: grupos desplegables (cumplidos, parciales, fallados…) con los íconos.
struct DaySummarySection: View {
    let day: Date
    let habits: [Habit]
    var onEdit: () -> Void

    @State private var expanded: Set<HabitDayStatus> = [.completed, .failed]

    var body: some View {
        Section {
            if groups.isEmpty {
                Text(Quotes.empty)
                    .labelCaps(12, .semibold)
            }
            ForEach(groups, id: \.status) { group in
                DisclosureGroup(isExpanded: binding(for: group.status)) {
                    ForEach(group.items, id: \.habit.id) { item in
                        HStack(spacing: Space.s) {
                            SymbolBadge(symbol: item.habit.symbol, colorHex: item.habit.colorHex, size: 28)
                            Text(item.habit.name)
                                .font(.ui(15, .semibold, relativeTo: .subheadline))
                                .textCase(.uppercase)
                                .foregroundStyle(.bone)
                            Spacer()
                            if let detail = item.detail {
                                Text(detail)
                                    .labelCaps(11, .semibold)
                                    .monospacedDigit()
                            }
                        }
                    }
                } label: {
                    HStack(spacing: Space.xs) {
                        StatusSwatch(status: group.status)
                            .frame(width: 14, height: 14)
                        Text("\(group.status.groupTitle) · \(group.items.count)")
                            .labelCaps(12, .black, color: .bone)
                        Spacer(minLength: Space.xxs)
                        IconStack(habits: group.items.map(\.habit))
                    }
                }
                .tint(.ash)
            }
            Button {
                onEdit()
            } label: {
                Label("Marcar o corregir este día", systemImage: "square.and.pencil")
                    .font(.ui(15, .semibold, relativeTo: .subheadline))
                    .foregroundStyle(.bone)
            }
        } header: {
            Text(title).labelCaps()
        }
    }

    private struct Item {
        let habit: Habit
        let detail: String?
    }

    private struct Group {
        let status: HabitDayStatus
        let items: [Item]
    }

    private var groups: [Group] {
        let order: [HabitDayStatus] = [.completed, .partial, .failed, .pending]
        var buckets: [HabitDayStatus: [Item]] = [:]
        for habit in habits {
            let evaluator = HabitEvaluator(habit: habit)
            let status = evaluator.status(on: day)
            guard order.contains(status) else { continue }
            var detail: String?
            if habit.kind == .quantity {
                detail = "\(NumberText.format(evaluator.value(on: day))) / \(NumberText.format(habit.target)) \(habit.unit)"
            }
            buckets[status, default: []].append(Item(habit: habit, detail: detail))
        }
        return order.compactMap { status in
            guard let items = buckets[status], !items.isEmpty else { return nil }
            return Group(status: status, items: items)
        }
    }

    private func binding(for status: HabitDayStatus) -> Binding<Bool> {
        Binding(
            get: { expanded.contains(status) },
            set: { isOn in
                if isOn { expanded.insert(status) } else { expanded.remove(status) }
            }
        )
    }

    private var title: String {
        if AppCalendar.calendar.isDateInToday(day) { return "Hoy" }
        if AppCalendar.calendar.isDateInYesterday(day) { return "Ayer" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(AppLocale.spanish)).capitalizedFirst
    }
}

/// Íconos superpuestos de varios hábitos (muestra hasta 5 y "+N").
struct IconStack: View {
    let habits: [Habit]
    private let maxVisible = 5

    var body: some View {
        HStack(spacing: -4) {
            ForEach(habits.prefix(maxVisible), id: \.id) { habit in
                SymbolBadge(symbol: habit.symbol, colorHex: habit.colorHex, size: 24)
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.sharp, style: .continuous)
                            .strokeBorder(.carbon, lineWidth: 1.5)
                    }
            }
            if habits.count > maxVisible {
                Text("+\(habits.count - maxVisible)")
                    .labelCaps(11, .black)
                    .padding(.leading, 10)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(habits.map(\.name).joined(separator: ", "))
    }
}

extension HabitDayStatus {
    var groupTitle: String {
        switch self {
        case .completed: return "Cumplidos"
        case .partial: return "Parciales"
        case .failed: return "Fallados"
        case .pending: return "Pendientes"
        case .notApplicable: return "No aplicaban"
        case .future: return ""
        }
    }
}

/// Todos los hábitos de un día, para marcarlos o corregirlos.
struct DayHabitsSheet: View {
    let day: Date

    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Habit> { $0.isArchived == false }, sort: \Habit.sortOrder)
    private var habits: [Habit]
    @State private var quantityHabit: Habit?

    var body: some View {
        NavigationStack {
            List {
                if !scheduled.isEmpty {
                    Section {
                        ForEach(scheduled) { habit in
                            HabitRowView(habit: habit, day: day) { quantityHabit = habit }
                        }
                    } header: {
                        Text("Tocaban este día").labelCaps()
                    }
                    .rowSurface()
                }
                if !others.isEmpty {
                    Section {
                        ForEach(others) { habit in
                            HabitRowView(habit: habit, day: day) { quantityHabit = habit }
                        }
                    } header: {
                        Text("Otros").labelCaps()
                    }
                    .rowSurface()
                }
            }
            .screenBackground()
            .navigationTitle(PosterHeader.dateLine(day))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .sheet(item: $quantityHabit) { habit in
                HabitDayEditorSheet(habit: habit, day: day)
            }
        }
        .presentationDetents([.medium, .large])
        .presentationBackground(Color.ink)
    }

    private var scheduled: [Habit] {
        habits.filter { HabitEvaluator(habit: $0).isScheduled(on: day) }
    }

    private var others: [Habit] {
        habits.filter { !HabitEvaluator(habit: $0).isScheduled(on: day) }
    }
}

#Preview {
    NavigationStack {
        HabitsCalendarView()
    }
    .modelContainer(PreviewData.container)
}
