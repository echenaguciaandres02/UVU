import SwiftUI
import SwiftData

struct HabitsHomeView: View {
    @Query(filter: #Predicate<Habit> { $0.isArchived == false }, sort: \Habit.sortOrder)
    private var habits: [Habit]

    @State private var showNewHabit = false
    @State private var showReorder = false
    @State private var showArchived = false
    @State private var showCalendar = false
    @State private var quantityHabit: Habit?

    var body: some View {
        NavigationStack {
            List {
                if !todayHabits.isEmpty {
                    Section("Hoy") {
                        ForEach(todayHabits) { habit in
                            NavigationLink(value: habit) {
                                HabitRowView(habit: habit, day: .now) { quantityHabit = habit }
                            }
                        }
                    }
                }
                if !otherHabits.isEmpty {
                    Section("No tocan hoy") {
                        ForEach(otherHabits) { habit in
                            NavigationLink(value: habit) {
                                HabitRowView(habit: habit, day: .now) { quantityHabit = habit }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Hábitos")
            .navigationDestination(for: Habit.self) { habit in
                HabitDetailView(habit: habit)
            }
            .navigationDestination(isPresented: $showCalendar) {
                HabitsCalendarView()
            }
            .navigationDestination(isPresented: $showArchived) {
                ArchivedHabitsView()
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                    }
                    .accessibilityLabel("Calendario general")
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Menu {
                        Button {
                            showReorder = true
                        } label: {
                            Label("Ordenar hábitos", systemImage: "arrow.up.arrow.down")
                        }
                        Button {
                            showArchived = true
                        } label: {
                            Label("Archivados", systemImage: "archivebox")
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                    }
                    .accessibilityLabel("Más opciones")

                    Button {
                        showNewHabit = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .accessibilityLabel("Nuevo hábito")
                }
            }
            .sheet(isPresented: $showNewHabit) {
                HabitFormView(habit: nil)
            }
            .sheet(isPresented: $showReorder) {
                ReorderHabitsView()
            }
            .sheet(item: $quantityHabit) { habit in
                HabitDayEditorSheet(habit: habit, day: .now)
            }
            .overlay {
                if habits.isEmpty {
                    ContentUnavailableView {
                        Label("Sin hábitos", systemImage: "checkmark.circle")
                    } description: {
                        Text("Toca + para crear tu primer hábito.")
                    }
                }
            }
        }
    }

    private var todayHabits: [Habit] {
        habits.filter { HabitEvaluator(habit: $0).isScheduled(on: .now) }
    }

    private var otherHabits: [Habit] {
        habits.filter { !HabitEvaluator(habit: $0).isScheduled(on: .now) }
    }
}

#Preview {
    HabitsHomeView()
        .modelContainer(PreviewData.container)
}
