import SwiftUI
import SwiftData

struct HabitsHomeView: View {
    @Query(filter: #Predicate<Habit> { $0.isArchived == false }, sort: \Habit.sortOrder)
    private var habits: [Habit]

    @State private var path: [HabitsRoute] = []
    @State private var showNewHabit = false
    @State private var showReorder = false
    @State private var quantityHabit: Habit?
    @State private var showDayComplete = false

    var body: some View {
        // Toda la navegación de la pestaña pasa por `path` y un único `navigationDestination`.
        // (Antes había destinos con `isPresented:` y la app se colgaba al abrir el calendario.)
        NavigationStack(path: $path) {
            List {
                if !todayHabits.isEmpty {
                    Section {
                        DayProgressHeader(done: doneTodayCount, total: todayHabits.count)
                            .listRowBackground(Color.clear)
                            .listRowInsets(EdgeInsets(top: 0, leading: Space.m, bottom: Space.s, trailing: Space.m))
                    }

                    Section {
                        ForEach(todayHabits) { habit in
                            NavigationLink(value: HabitsRoute.detail(habit)) {
                                HabitRowView(habit: habit, day: .now) { quantityHabit = habit }
                            }
                            .rowSurface()
                        }
                    } header: {
                        Text("Hoy").labelCaps()
                    }
                }
                if !otherHabits.isEmpty {
                    Section {
                        ForEach(otherHabits) { habit in
                            NavigationLink(value: HabitsRoute.detail(habit)) {
                                HabitRowView(habit: habit, day: .now) { quantityHabit = habit }
                            }
                            .rowSurface()
                        }
                    } header: {
                        Text("No tocan hoy").labelCaps()
                    }
                }
            }
            .screenBackground()
            .navigationTitle("HÁBITOS")
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
                            .fontWeight(.bold)
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
                        Image(systemName: "ellipsis")
                            .fontWeight(.bold)
                    }
                    .accessibilityLabel("Más opciones")

                    Button {
                        showNewHabit = true
                    } label: {
                        Image(systemName: "plus")
                            .fontWeight(.bold)
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
                    VStack(spacing: Space.m) {
                        RedPoster(text: Quotes.empty, caption: "Toca + para crear un hábito", minHeight: 260)
                    }
                    .padding(Space.m)
                }
            }
        }
        .overlay {
            if showDayComplete {
                DayCompleteOverlay()
                    .transition(.opacity)
                    .onTapGesture { withAnimation(Motion.quick) { showDayComplete = false } }
            }
        }
        .onChange(of: allDoneToday) { wasDone, isDone in
            guard isDone, !wasDone else { return }
            celebrate()
        }
    }

    private var todayHabits: [Habit] {
        habits.filter { HabitEvaluator(habit: $0).isScheduled(on: .now) }
    }

    private var otherHabits: [Habit] {
        habits.filter { !HabitEvaluator(habit: $0).isScheduled(on: .now) }
    }

    private var doneTodayCount: Int {
        todayHabits.filter { HabitActions.isCompleted($0, on: .now) }.count
    }

    private var allDoneToday: Bool {
        !todayHabits.isEmpty && doneTodayCount == todayHabits.count
    }

    /// Pantalla roja breve al completar todo el día.
    private func celebrate() {
        Haptics.success()
        withAnimation(Motion.quick) { showDayComplete = true }
        Task {
            try? await Task.sleep(for: .seconds(1.8))
            withAnimation(Motion.quick) { showDayComplete = false }
        }
    }
}

/// "4 / 8" en números finos y la barra del día.
private struct DayProgressHeader: View {
    let done: Int
    let total: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                Text("\(done)")
                    .font(.numeral(64))
                    .foregroundStyle(.bone)
                    .contentTransition(.numericText(value: Double(done)))
                Text("/ \(total)")
                    .font(.numeral(28, weight: .thin))
                    .foregroundStyle(.ash)
                Spacer()
                Text(done == total ? "Día completo" : "Hechos hoy")
                    .labelCaps(12, .semibold, color: done == total ? .bone : .ash)
            }
            .monospacedDigit()
            QuantityBar(progress: total == 0 ? 0 : Double(done) / Double(total), accent: true)
        }
        .animation(Motion.quick, value: done)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(done) de \(total) hábitos hechos hoy")
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
        .preferredColorScheme(.dark)
}
