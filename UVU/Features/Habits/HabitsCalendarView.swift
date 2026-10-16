import SwiftUI
import SwiftData

/// Calendario general: el color de cada día resume todos los hábitos activos.
struct HabitsCalendarView: View {
    @Query(filter: #Predicate<Habit> { $0.isArchived == false }, sort: \Habit.sortOrder)
    private var habits: [Habit]

    @State private var month = Date.now
    @State private var selectedDay: SelectedDay?

    var body: some View {
        let evaluators = habits.map { HabitEvaluator(habit: $0) }

        List {
            Section {
                MonthCalendarView(month: $month) { day in
                    let status = HabitSummary.combinedStatus(evaluators, on: day)
                    Button {
                        selectedDay = SelectedDay(date: day)
                    } label: {
                        CalendarDayCell(date: day, fill: status.fillColor, textColor: status.textColor,
                                        accessibilityStatus: status.title)
                    }
                    .buttonStyle(.borderless)
                    .disabled(status == .future)
                }
                HabitStatusLegend()
            } footer: {
                Text("Verde: todos cumplidos. Amarillo: algunos. Rojo: ninguno. Toca un día para ver el detalle o corregirlo.")
            }
        }
        .navigationTitle("Calendario general")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedDay) { selection in
            DayHabitsSheet(day: selection.date)
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
