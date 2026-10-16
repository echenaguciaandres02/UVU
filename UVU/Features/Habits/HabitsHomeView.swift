import SwiftUI
import SwiftData

struct HabitsHomeView: View {
    @Query(filter: #Predicate<Habit> { $0.isArchived == false }, sort: \Habit.sortOrder)
    private var habits: [Habit]

    @State private var path: [HabitsRoute] = []
    @State private var showNewHabit = false
    @State private var showReorder = false
    @State private var quantityHabit: Habit?

    var body: some View {
        // Toda la navegación de la pestaña pasa por `path` y un único `navigationDestination`.
        // (Antes había destinos con `isPresented:` y la app se colgaba al abrir el calendario.)
        NavigationStack(path: $path) {
            List {
                if !todayHabits.isEmpty {
                    Section("Hoy") {
                        ForEach(todayHabits) { habit in
                            NavigationLink(value: HabitsRoute.detail(habit)) {
                                HabitRowView(habit: habit, day: .now) { quantityHabit = habit }
                            }
                        }
                    }
                }
                if !otherHabits.isEmpty {
                    Section("No tocan hoy") {
                        ForEach(otherHabits) { habit in
                            NavigationLink(value: HabitsRoute.detail(habit)) {
                                HabitRowView(habit: habit, day: .now) { quantityHabit = habit }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Hábitos")
            .navigationDestination(for: HabitsRoute.self) { route in
                switch route {
                case .detail(let habit):
                    HabitDetailView(habit: habit)
                case .calendar:
                    HabitsCalendarView()
                case .archived:
                    ArchivedHabitsView()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        path.append(.calendar)
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
                            path.append(.archived)
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

enum HabitsRoute: Hashable {
    case detail(Habit)
    case calendar
    case archived
}

#Preview {
    HabitsHomeView()
        .modelContainer(PreviewData.container)
}
