import SwiftUI
import SwiftData

/// Pantalla Hoy: saludo, frase del día, hábitos para marcar, tareas de hoy, próximos avisos,
/// el entreno y el journal del día. El calendario unificado y Ajustes se abren desde la barra.
struct TodayView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Habit> { $0.isArchived == false }, sort: \Habit.sortOrder)
    private var habits: [Habit]
    @Query(sort: \TaskItem.createdAt) private var tasks: [TaskItem]
    @Query(sort: \Routine.sortOrder) private var routines: [Routine]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \JournalEntry.date, order: .reverse) private var entries: [JournalEntry]
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg

    @State private var path: [TodayRoute] = []
    @State private var showCalendar = false
    @State private var showSettings = false
    @State private var quantityHabit: Habit?
    @State private var editingTask: TaskItem?
    @State private var showNewTask = false
    @State private var showSession = false
    @State private var journalDay: SelectedDay?
    @State private var lock = JournalLock.shared

    var body: some View {
        let todayHabits = TodayAgenda.todayHabits(habits)
        let todayTasks = TodayAgenda.todayTasks(tasks)

        NavigationStack(path: $path) {
            List {
                Section {
                    header
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: Space.m, bottom: Space.s, trailing: Space.m))
                    quotePoster
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: Space.m, bottom: 0, trailing: Space.m))
                }
                .listRowSeparator(.hidden)

                habitsSection(todayHabits)
                tasksSection(todayTasks)
                remindersSection
                workoutSection
                journalSection
            }
            .screenBackground()
            .navigationDestination(for: TodayRoute.self) { route in
                switch route {
                case .habit(let habit):
                    HabitDetailView(habit: habit)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showCalendar = true
                    } label: {
                        Image(systemName: "calendar")
                            .fontWeight(.bold)
                    }
                    .accessibilityLabel("Calendario")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .fontWeight(.bold)
                    }
                    .accessibilityLabel("Ajustes")
                }
            }
            .sheet(isPresented: $showCalendar) {
                UnifiedCalendarView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(item: $quantityHabit) { habit in
                HabitDayEditorSheet(habit: habit, day: .now)
            }
            .sheet(item: $editingTask) { task in
                TaskFormView(task: task)
            }
            .sheet(isPresented: $showNewTask) {
                TaskFormView(task: nil, defaultDue: .now)
            }
            .sheet(item: $journalDay) { selection in
                JournalEditorView(day: selection.date)
            }
            .fullScreenCover(isPresented: $showSession) {
                LiveSessionView()
            }
        }
    }

    // MARK: - Cabecera

    private var header: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(greeting)
                .labelCaps(13, .semibold, color: .ash)
            PosterHeader(title: "Hoy.", subtitle: PosterHeader.dateLine(), size: 96)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    /// Póster más bajo que antes, para que los hábitos se vean sin bajar mucho.
    private var quotePoster: some View {
        RedPoster(text: Quotes.quotedOfTheDay(), caption: "Frase del día", minHeight: 150,
                  textSize: 34, topInset: 38)
            .overlay(alignment: .topTrailing) {
                TapeLabel(text: "DO.")
                    .scaleEffect(0.8, anchor: .topTrailing)
                    .padding(Space.s)
            }
    }

    private var greeting: String {
        switch AppCalendar.calendar.component(.hour, from: .now) {
        case 4..<12: return "Buenos días"
        case 12..<19: return "Buenas tardes"
        default: return "Buenas noches"
        }
    }

    // MARK: - Hábitos

    @ViewBuilder
    private func habitsSection(_ todayHabits: [Habit]) -> some View {
        if !todayHabits.isEmpty {
            let done = todayHabits.filter { HabitActions.isCompleted($0, on: .now) }.count
            Section {
                DayProgressHeader(done: done, total: todayHabits.count)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: Space.m, bottom: Space.s, trailing: Space.m))
                ForEach(todayHabits) { habit in
                    NavigationLink(value: TodayRoute.habit(habit)) {
                        HabitRowView(habit: habit, day: .now) { quantityHabit = habit }
                    }
                    .rowSurface()
                }
            } header: {
                SectionTitle(title: "Hábitos")
            }
        }
    }

    // MARK: - Tareas

    private func tasksSection(_ todayTasks: [TaskItem]) -> some View {
        Section {
            if todayTasks.isEmpty {
                Text("Nada pendiente hoy.")
                    .labelCaps(12, .semibold)
                    .padding(.vertical, Space.xs)
                    .rowSurface()
            }
            ForEach(todayTasks) { task in
                TaskRowView(task: task) { editingTask = task }
                    .taskRowSurface(task.list)
            }
        } header: {
            SectionTitle(title: "Tareas", count: todayTasks.isEmpty ? nil : todayTasks.count) {
                Button {
                    showNewTask = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .black))
                        .foregroundStyle(.bone)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Nueva tarea para hoy")
            }
        }
    }

    // MARK: - Próximos avisos

    @ViewBuilder
    private var remindersSection: some View {
        let reminders = TodayAgenda.upcomingReminders(habits: habits, tasks: tasks)
        if !reminders.isEmpty {
            Section {
                // Se recalcula cada minuto: un aviso desaparece cuando ya sonó.
                TimelineView(.everyMinute) { timeline in
                    let upcoming = TodayAgenda.upcomingReminders(habits: habits, tasks: tasks, now: timeline.date)
                    VStack(spacing: 0) {
                        ForEach(Array(upcoming.prefix(6).enumerated()), id: \.element.id) { index, reminder in
                            ReminderRow(reminder: reminder)
                            if index < min(upcoming.count, 6) - 1 {
                                Divider().overlay(Color.graphite)
                            }
                        }
                        if upcoming.isEmpty {
                            Text("Sin más avisos hoy.")
                                .labelCaps(12, .semibold)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.vertical, Space.xs)
                        }
                    }
                }
                .rowSurface()
            } header: {
                SectionTitle(title: "Próximos avisos")
            }
        }
    }

    // MARK: - Entreno

    private var activeSession: WorkoutSession? {
        sessions.first(where: \.isActive)
    }

    private var finishedToday: WorkoutSession? {
        sessions.first { !$0.isActive && AppCalendar.calendar.isDateInToday($0.startedAt) }
    }

    private var todaysRoutine: Routine? {
        let weekday = AppCalendar.weekday(of: .now)
        return routines.first { $0.weekdays.contains(weekday) }
    }

    private var workoutSection: some View {
        Section {
            workoutCard
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 0, leading: Space.m, bottom: 0, trailing: Space.m))
        } header: {
            SectionTitle(title: "Entreno")
        }
    }

    @ViewBuilder
    private var workoutCard: some View {
        if let active = activeSession {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Sesión en curso").labelCaps(12, .black, color: .bone)
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    Text(GymMath.duration(timeline.date.timeIntervalSince(active.startedAt)))
                        .font(.numeral(44))
                        .monospacedDigit()
                        .foregroundStyle(.bone)
                }
                Text(active.routine?.name ?? "Entreno libre").labelCaps(12, .semibold)
                Button("Volver al entreno") { showSession = true }
                    .buttonStyle(.uvuPrimary)
            }
            .cardSurface()
        } else if let done = finishedToday {
            HStack(spacing: Space.s) {
                HabitCheckbox(progress: 1, size: 26)
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text("Entreno hecho").labelCaps(12, .black, color: .bone)
                    Text(workoutSummary(done)).labelCaps(11, .semibold)
                }
                Spacer()
            }
            .cardSurface()
            .accessibilityElement(children: .combine)
        } else if let routine = todaysRoutine {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Hoy toca").labelCaps(12, .black, color: .bone)
                Text(routine.name).posterTitle(40, relativeTo: .title)
                Text("\(routine.sortedItems.count) ejercicios").labelCaps(11, .semibold)
                Button("Empezar entreno") { start(routine) }
                    .buttonStyle(.uvuPrimary)
            }
            .cardSurface()
        } else {
            HStack(spacing: Space.s) {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text("Sin rutina para hoy").labelCaps(12, .black, color: .bone)
                    Text("Descanso, o entrena libre.")
                        .font(.uiCallout)
                        .foregroundStyle(.ash)
                }
                Spacer(minLength: Space.xs)
                Button("Entreno libre") { start(nil) }
                    .buttonStyle(.borderless)
                    .font(.ui(13, .black))
                    .textCase(.uppercase)
                    .foregroundStyle(.bone)
                    .padding(.horizontal, Space.s)
                    .frame(minHeight: 40)
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.sharp, style: .continuous)
                            .strokeBorder(.graphite, lineWidth: 1.5)
                    }
            }
            .cardSurface()
        }
    }

    private func workoutSummary(_ session: WorkoutSession) -> String {
        let name = session.routine?.name ?? "Entreno libre"
        guard let end = session.endedAt else { return name }
        return "\(name) · \(GymMath.duration(end.timeIntervalSince(session.startedAt)))"
    }

    private func start(_ routine: Routine?) {
        WorkoutActions.start(routine: routine, unit: weightUnit, in: context)
        Haptics.stamp()
        showSession = true
    }

    // MARK: - Journal

    private var journalSection: some View {
        let today = entries.first { AppCalendar.calendar.isDateInToday($0.date) }
        return Section {
            TodayJournalSummary(entry: today, isLocked: !lock.allowsAccess) {
                openJournal()
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 0, leading: Space.m, bottom: Space.l, trailing: Space.m))
        } header: {
            SectionTitle(title: "Journal")
        }
    }

    /// Con Face ID activado, primero se desbloquea el journal.
    private func openJournal() {
        let day = AppCalendar.startOfDay(.now)
        if lock.allowsAccess {
            journalDay = SelectedDay(date: day)
            return
        }
        Task {
            await lock.unlock()
            if lock.allowsAccess { journalDay = SelectedDay(date: day) }
        }
    }
}

enum TodayRoute: Hashable {
    case habit(Habit)
}

// MARK: - Piezas

/// Título de sección de Hoy: etiqueta en mayúsculas, número opcional y un botón a la derecha.
private struct SectionTitle<Trailing: View>: View {
    let title: String
    var count: Int?
    @ViewBuilder var trailing: () -> Trailing

    var body: some View {
        HStack(spacing: Space.xs) {
            Text(title).labelCaps(12, .black, color: .bone)
            if let count {
                Text("\(count)").labelCaps(12, .semibold)
            }
            Spacer()
            trailing()
        }
        .padding(.top, Space.s)
    }
}

extension SectionTitle where Trailing == EmptyView {
    init(title: String, count: Int? = nil) {
        self.init(title: title, count: count) { EmptyView() }
    }
}

/// Un aviso: hora en números finos, ícono y título.
private struct ReminderRow: View {
    let reminder: AgendaReminder

    var body: some View {
        HStack(spacing: Space.s) {
            Text(reminder.date.formatted(Date.FormatStyle(date: .omitted, time: .shortened).locale(AppLocale.spanish)))
                .font(.numeral(22, weight: .thin))
                .monospacedDigit()
                .foregroundStyle(.bone)
                .frame(minWidth: 64, alignment: .leading)
            SymbolBadge(symbol: reminder.symbol, colorHex: reminder.colorHex, size: 24)
            Text(reminder.title)
                .font(.ui(15, .semibold, relativeTo: .subheadline))
                .foregroundStyle(.bone)
                .lineLimit(2)
            Spacer(minLength: 0)
            Image(systemName: reminder.kind == .habit ? "repeat" : "bell.fill")
                .font(.system(size: 10, weight: .bold))
                .foregroundStyle(.ash)
        }
        .padding(.vertical, Space.xs)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(reminder.title), aviso a las \(reminder.date.formatted(date: .omitted, time: .shortened))")
    }
}

/// Journal del día en Hoy: invita a escribir o muestra el ánimo. Si está protegido, no enseña nada.
private struct TodayJournalSummary: View {
    let entry: JournalEntry?
    let isLocked: Bool
    var onOpen: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            if isLocked {
                HStack(spacing: Space.xs) {
                    Image(systemName: "lock.fill").foregroundStyle(.ash)
                    Text(entry == nil ? "Sin escribir hoy" : "Escrito hoy").labelCaps(12, .black, color: .bone)
                }
                Button("Abrir el journal", action: onOpen)
                    .buttonStyle(.uvuSecondary)
            } else if let entry {
                HStack(spacing: Space.s) {
                    MoodBars(level: entry.mood)
                    Text(Mood.title(entry.mood)).labelCaps(12, .black, color: .bone)
                }
                if !entry.excerpt.isEmpty {
                    Text(entry.excerpt)
                        .font(.editorial(19, relativeTo: .title3))
                        .foregroundStyle(.bone)
                        .lineLimit(2)
                }
                Button("Seguir escribiendo", action: onOpen)
                    .buttonStyle(.uvuSecondary)
            } else {
                Text("¿Cómo fue tu día?")
                    .editorialQuote(26)
                    .frame(maxWidth: .infinity)
                Button("Escribir en el journal", action: onOpen)
                    .buttonStyle(.uvuSecondary)
            }
        }
        .cardSurface()
    }
}

#Preview {
    TodayView()
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.dark)
}
