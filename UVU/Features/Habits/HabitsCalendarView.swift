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
                        withAnimation(.snappy) { selectedDay = day }
                        Haptics.tap()
                    } label: {
                        CalendarDayCell(date: day, fill: status.fillColor, textColor: status.textColor,
                                        accessibilityStatus: status.title)
                            .overlay {
                                if isSelected {
                                    Circle()
                                        .strokeBorder(Color.primary, lineWidth: 2)
                                        .frame(width: 44, height: 44)
                                }
                            }
                    }
                    .buttonStyle(.borderless)
                    .disabled(status == .future)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
                HabitStatusLegend()
            } footer: {
                Text("Verde: todos cumplidos. Amarillo: algunos. Rojo: ninguno.")
            }

            DaySummarySection(day: selectedDay, habits: habits) {
                editingDay = SelectedDay(date: selectedDay)
            }
        }
        .navigationTitle("Calendario general")
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
                Text("Ningún hábito tocaba este día.")
                    .foregroundStyle(.secondary)
            }
            ForEach(groups, id: \.status) { group in
                DisclosureGroup(isExpanded: binding(for: group.status)) {
                    ForEach(group.items, id: \.habit.id) { item in
                        HStack(spacing: 12) {
                            SymbolBadge(symbol: item.habit.symbol, colorHex: item.habit.colorHex, size: 28)
                            Text(item.habit.name)
                            Spacer()
                            if let detail = item.detail {
                                Text(detail)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                    .monospacedDigit()
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(group.status.fillColor ?? Color(.systemGray3))
                            .frame(width: 10, height: 10)
                        Text("\(group.status.groupTitle) (\(group.items.count))")
                            .foregroundStyle(.primary)
                        Spacer(minLength: 4)
                        IconStack(habits: group.items.map(\.habit))
                    }
                }
            }
            Button {
                onEdit()
            } label: {
                Label("Marcar o corregir este día", systemImage: "square.and.pencil")
            }
        } header: {
            Text(title)
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
        HStack(spacing: -6) {
            ForEach(habits.prefix(maxVisible), id: \.id) { habit in
                SymbolBadge(symbol: habit.symbol, colorHex: habit.colorHex, size: 24)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6, style: .continuous)
                            .strokeBorder(Color(.secondarySystemGroupedBackground), lineWidth: 1.5)
                    }
            }
            if habits.count > maxVisible {
                Text("+\(habits.count - maxVisible)")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
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
                    Section("Tocaban este día") {
                        ForEach(scheduled) { habit in
                            HabitRowView(habit: habit, day: day) { quantityHabit = habit }
                        }
                    }
                }
                if !others.isEmpty {
                    Section("Otros") {
                        ForEach(others) { habit in
                            HabitRowView(habit: habit, day: day) { quantityHabit = habit }
                        }
                    }
                }
            }
            .navigationTitle(title)
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
    }

    private var scheduled: [Habit] {
        habits.filter { HabitEvaluator(habit: $0).isScheduled(on: day) }
    }

    private var others: [Habit] {
        habits.filter { !HabitEvaluator(habit: $0).isScheduled(on: day) }
    }

    private var title: String {
        day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(AppLocale.spanish)).capitalizedFirst
    }
}

#Preview {
    NavigationStack {
        HabitsCalendarView()
    }
    .modelContainer(PreviewData.container)
}
