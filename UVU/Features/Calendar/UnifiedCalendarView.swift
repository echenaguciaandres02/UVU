import SwiftUI
import SwiftData

/// Calendario unificado (se abre desde Hoy). Cada día muestra el cuadro de los hábitos
/// (rojo, rojo oscuro, tachado) y debajo marcas pequeñas: entreno, journal y tareas hechas.
/// Al tocar un día se ve todo lo que pasó: hábitos, entrenos, tareas completadas y el journal.
struct UnifiedCalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<Habit> { $0.isArchived == false }, sort: \Habit.sortOrder)
    private var habits: [Habit]
    @Query(sort: \WorkoutSession.startedAt) private var sessions: [WorkoutSession]
    @Query(sort: \TaskItem.createdAt) private var tasks: [TaskItem]
    @Query(sort: \JournalEntry.date) private var entries: [JournalEntry]

    @State private var month = Date.now
    @State private var selectedDay = AppCalendar.startOfDay(.now)
    @State private var path: [CalendarRoute] = []
    @State private var editingHabitsDay: SelectedDay?
    @State private var journalDay: SelectedDay?
    @State private var lock = JournalLock.shared

    var body: some View {
        let evaluators = habits.map { HabitEvaluator(habit: $0) }
        let index = DayActivityIndex(sessions: sessions, tasks: tasks, entries: entries)

        NavigationStack(path: $path) {
            List {
                Section {
                    MonthCalendarView(month: $month) { day in
                        let status = HabitSummary.combinedStatus(evaluators, on: day)
                        let isFuture = AppCalendar.startOfDay(day) > AppCalendar.startOfDay(.now)
                        let isSelected = AppCalendar.calendar.isDate(day, inSameDayAs: selectedDay)
                        Button {
                            withAnimation(Motion.quick) { selectedDay = AppCalendar.startOfDay(day) }
                            Haptics.tap()
                        } label: {
                            UnifiedDayCell(date: day, status: status, isSelected: isSelected,
                                           workout: !index.workouts(on: day).isEmpty,
                                           journal: index.journalEntry(on: day) != nil,
                                           tasksDone: !index.completedTasks(on: day).isEmpty)
                        }
                        .buttonStyle(.borderless)
                        .disabled(isFuture)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                    }
                    .padding(.vertical, Space.xs)
                    HabitStatusLegend()
                    ActivityMarksLegend()
                        .padding(.bottom, Space.xs)
                }
                .rowSurface()

                DaySummarySection(day: selectedDay, habits: habits) {
                    editingHabitsDay = SelectedDay(date: selectedDay)
                }
                .rowSurface()

                workoutsSection(index.workouts(on: selectedDay))
                tasksSection(index.completedTasks(on: selectedDay))
                journalSection(index.journalEntry(on: selectedDay))
            }
            .screenBackground()
            .navigationTitle("CALENDARIO")
            .navigationBarTitleDisplayMode(.inline)
            .navigationDestination(for: CalendarRoute.self) { route in
                switch route {
                case .session(let session):
                    SessionDetailView(session: session)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
            .sheet(item: $editingHabitsDay) { selection in
                DayHabitsSheet(day: selection.date)
            }
            .sheet(item: $journalDay) { selection in
                JournalEditorView(day: selection.date)
            }
        }
        .presentationBackground(Color.ink)
    }

    // MARK: - Entrenos

    private func workoutsSection(_ workouts: [WorkoutSession]) -> some View {
        Section {
            if workouts.isEmpty {
                emptyRow("Sin entreno")
            }
            ForEach(workouts) { session in
                NavigationLink(value: CalendarRoute.session(session)) {
                    HStack(spacing: Space.s) {
                        Image(systemName: "dumbbell.fill")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.bone)
                            .frame(width: 28, height: 28)
                        VStack(alignment: .leading, spacing: Space.xxs) {
                            Text(session.routine?.name ?? "Entreno libre")
                                .font(.ui(15, .semibold, relativeTo: .subheadline))
                                .textCase(.uppercase)
                                .foregroundStyle(.bone)
                            Text(workoutDetail(session)).labelCaps(10, .semibold)
                        }
                    }
                }
            }
        } header: {
            Text("Entreno").labelCaps()
        }
        .rowSurface()
    }

    private func workoutDetail(_ session: WorkoutSession) -> String {
        let sets = session.sortedExercises.reduce(0) { $0 + $1.sortedSets.count }
        var parts = [session.startedAt.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(AppLocale.spanish))]
        if let end = session.endedAt {
            parts.append(GymMath.duration(end.timeIntervalSince(session.startedAt)))
        }
        parts.append("\(sets) series")
        return parts.joined(separator: " · ")
    }

    // MARK: - Tareas

    private func tasksSection(_ done: [TaskItem]) -> some View {
        Section {
            if done.isEmpty {
                emptyRow("Ninguna tarea completada")
            }
            ForEach(done) { task in
                HStack(spacing: Space.s) {
                    HabitCheckbox(progress: 1, size: 20)
                    Text(task.title)
                        .font(.ui(15, .semibold, relativeTo: .subheadline))
                        .foregroundStyle(.bone)
                    Spacer(minLength: Space.xs)
                    if let list = task.list {
                        SymbolBadge(symbol: list.symbol, colorHex: list.colorHex, size: 22)
                            .accessibilityLabel(list.name)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        } header: {
            HStack {
                Text("Tareas completadas").labelCaps()
                Spacer()
                if !done.isEmpty { Text("\(done.count)").labelCaps() }
            }
        }
        .rowSurface()
    }

    // MARK: - Journal

    private func journalSection(_ entry: JournalEntry?) -> some View {
        Section {
            Button {
                openJournal()
            } label: {
                VStack(alignment: .leading, spacing: Space.xs) {
                    if !lock.allowsAccess {
                        HStack(spacing: Space.xs) {
                            Image(systemName: "lock.fill").foregroundStyle(.ash)
                            Text(entry == nil ? "Sin entrada" : "Entrada protegida")
                                .labelCaps(12, .black, color: .bone)
                        }
                    } else if let entry {
                        HStack(spacing: Space.s) {
                            MoodBars(level: entry.mood, height: 14, barWidth: 3)
                            Text(Mood.title(entry.mood)).labelCaps(11, .black, color: .bone)
                        }
                        if !entry.excerpt.isEmpty {
                            Text(entry.excerpt)
                                .font(.editorial(18, relativeTo: .body))
                                .foregroundStyle(.bone)
                                .lineLimit(3)
                                .multilineTextAlignment(.leading)
                        }
                    } else {
                        Text("Sin entrada").labelCaps(12, .semibold)
                    }
                    Text(entry == nil ? "Escribir este día" : "Abrir la entrada")
                        .font(.ui(15, .semibold, relativeTo: .subheadline))
                        .foregroundStyle(.bone)
                        .padding(.top, Space.xxs)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        } header: {
            Text("Journal").labelCaps()
        }
        .rowSurface()
    }

    private func openJournal() {
        let day = selectedDay
        if lock.allowsAccess {
            journalDay = SelectedDay(date: day)
            return
        }
        Task {
            await lock.unlock()
            if lock.allowsAccess { journalDay = SelectedDay(date: day) }
        }
    }

    private func emptyRow(_ text: String) -> some View {
        Text(text)
            .labelCaps(12, .semibold)
            .padding(.vertical, Space.xxs)
    }
}

enum CalendarRoute: Hashable {
    case session(WorkoutSession)
}

// MARK: - Celda y leyenda

/// Día del calendario unificado: el cuadro de hábitos y, debajo, las marcas del día.
private struct UnifiedDayCell: View {
    let date: Date
    let status: HabitDayStatus
    let isSelected: Bool
    let workout: Bool
    let journal: Bool
    let tasksDone: Bool

    var body: some View {
        VStack(spacing: 2) {
            CalendarDayCell(date: date, status: status, isSelected: isSelected)
                .accessibilityHidden(true)
            // Siempre las tres posiciones (vacías si no hay nada) para que todas las filas midan igual.
            HStack(spacing: 3) {
                ActivityMark(kind: .workout).opacity(workout ? 1 : 0)
                ActivityMark(kind: .journal).opacity(journal ? 1 : 0)
                ActivityMark(kind: .tasks).opacity(tasksDone ? 1 : 0)
            }
            .frame(height: 9)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        var parts = [date.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(AppLocale.spanish))]
        if AppCalendar.calendar.isDateInToday(date) { parts.insert("Hoy", at: 0) }
        if !status.title.isEmpty { parts.append("hábitos: \(status.title)") }
        if workout { parts.append("entrenó") }
        if journal { parts.append("con journal") }
        if tasksDone { parts.append("tareas completadas") }
        return parts.joined(separator: ", ")
    }
}

/// Marca pequeña bajo el día: entreno, journal o tareas hechas.
struct ActivityMark: View {
    enum Kind: CaseIterable {
        case workout
        case journal
        case tasks

        var symbol: String {
            switch self {
            case .workout: return "dumbbell.fill"
            case .journal: return "book.closed.fill"
            case .tasks: return "checkmark"
            }
        }

        var title: String {
            switch self {
            case .workout: return "Entreno"
            case .journal: return "Journal"
            case .tasks: return "Tareas"
            }
        }
    }

    let kind: Kind
    var size: CGFloat = 7

    var body: some View {
        Image(systemName: kind.symbol)
            .font(.system(size: size, weight: .black))
            .foregroundStyle(.bone)
    }
}

private struct ActivityMarksLegend: View {
    var body: some View {
        HStack(spacing: Space.m) {
            ForEach(ActivityMark.Kind.allCases, id: \.self) { kind in
                HStack(spacing: Space.xs) {
                    ActivityMark(kind: kind, size: 10)
                        .frame(width: 14)
                    Text(kind.title).labelCaps(10, .semibold).fixedSize()
                }
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Marcas bajo cada día: entreno, journal y tareas completadas")
    }
}

#Preview {
    UnifiedCalendarView()
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.dark)
}
