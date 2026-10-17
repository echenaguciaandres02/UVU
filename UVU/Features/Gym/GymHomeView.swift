import SwiftUI
import SwiftData

enum GymScope: String, CaseIterable, Identifiable {
    case routines
    case summary
    case history
    case exercises

    var id: String { rawValue }

    var title: String {
        switch self {
        case .routines: return "Rutinas"
        case .summary: return "Resumen"
        case .history: return "Historial"
        case .exercises: return "Ejercicios"
        }
    }
}

enum GymRoute: Hashable {
    case routine(Routine)
    case session(WorkoutSession)
    case exercise(Exercise)
}

struct GymHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Routine.sortOrder) private var routines: [Routine]
    @Query(sort: \WorkoutSession.startedAt, order: .reverse) private var sessions: [WorkoutSession]
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg

    @State private var scope: GymScope = .routines
    @State private var path: [GymRoute] = []
    @State private var showSession = false
    @State private var showNewExercise = false
    @State private var exerciseQuery = ""

    var body: some View {
        NavigationStack(path: $path) {
            List {
                Section {
                    headerCard
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: Space.xs, leading: Space.m, bottom: Space.xs, trailing: Space.m))

                    ScopeBar(options: GymScope.allCases, selection: $scope, title: \.title)
                        .listRowBackground(Color.clear)
                        .listRowInsets(EdgeInsets(top: 0, leading: Space.m, bottom: 0, trailing: Space.m))
                }

                switch scope {
                case .routines: routinesSection
                case .summary: GymSummarySections(sessions: sessions, unit: weightUnit)
                case .history: historySections
                case .exercises: exercisesSections
                }
            }
            .screenBackground()
            .navigationTitle("GYM")
            .navigationDestination(for: GymRoute.self) { route in
                switch route {
                case .routine(let routine): RoutineEditorView(routine: routine)
                case .session(let session): SessionDetailView(session: session)
                case .exercise(let exercise): ExerciseProgressView(exercise: exercise)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        switch scope {
                        case .routines, .summary, .history: newRoutine()
                        case .exercises: showNewExercise = true
                        }
                    } label: {
                        Image(systemName: "plus").fontWeight(.bold)
                    }
                    .accessibilityLabel(scope == .exercises ? "Nuevo ejercicio" : "Nueva rutina")
                }
            }
            .sheet(isPresented: $showNewExercise) {
                ExerciseFormView()
            }
            .fullScreenCover(isPresented: $showSession) {
                LiveSessionView()
            }
        }
    }

    // MARK: - Cabecera

    private var activeSession: WorkoutSession? {
        sessions.first(where: \.isActive)
    }

    private var todaysRoutines: [Routine] {
        let weekday = AppCalendar.weekday(of: .now)
        return routines.filter { $0.weekdays.contains(weekday) }
    }

    @ViewBuilder
    private var headerCard: some View {
        if let active = activeSession {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Sesión en curso").labelCaps(12, .black, color: .bone)
                TimelineView(.periodic(from: .now, by: 1)) { timeline in
                    Text(GymMath.duration(timeline.date.timeIntervalSince(active.startedAt)))
                        .font(.numeral(56))
                        .monospacedDigit()
                        .foregroundStyle(.bone)
                }
                Text(active.routine?.name ?? "Entreno libre").labelCaps(12, .semibold)
                Button("Volver al entreno") { showSession = true }
                    .buttonStyle(.uvuPrimary)
            }
            .cardSurface()
        } else if let routine = todaysRoutines.first {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Hoy toca").labelCaps(12, .black, color: .bone)
                Text(routine.name).posterTitle(48, relativeTo: .title)
                Text("\(routine.sortedItems.count) ejercicios · \(routine.weekdaysDescription)").labelCaps(11, .semibold)
                Button("Empezar") { start(routine) }
                    .buttonStyle(.uvuPrimary)
            }
            .cardSurface()
        } else {
            VStack(alignment: .leading, spacing: Space.s) {
                Text("Sin rutina para hoy").labelCaps(12, .black, color: .bone)
                Text("Elige una rutina abajo o entrena libre.")
                    .font(.uiCallout)
                    .foregroundStyle(.ash)
                Button("Entreno libre") { start(nil) }
                    .buttonStyle(.uvuSecondary)
            }
            .cardSurface()
        }
    }

    // MARK: - Rutinas

    @ViewBuilder
    private var routinesSection: some View {
        if routines.isEmpty {
            Section {
                RedPoster(text: Quotes.empty, caption: "Toca + para crear una rutina", minHeight: 180)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        } else {
            Section {
                ForEach(routines) { routine in
                    HStack(spacing: Space.s) {
                        NavigationLink(value: GymRoute.routine(routine)) {
                            VStack(alignment: .leading, spacing: Space.xxs) {
                                Text(routine.name)
                                    .font(.display(26, relativeTo: .title3))
                                    .textCase(.uppercase)
                                    .foregroundStyle(.bone)
                                Text("\(routine.sortedItems.count) ejercicios · \(routine.weekdaysDescription)")
                                    .labelCaps(10, .semibold)
                            }
                        }
                        Button {
                            start(routine)
                        } label: {
                            // Contorno: el rojo con volumen queda para "Hoy toca".
                            Image(systemName: "play.fill")
                                .font(.system(size: 14, weight: .black))
                                .foregroundStyle(.bone)
                                .frame(width: 40, height: 40)
                                .overlay {
                                    RoundedRectangle(cornerRadius: Radius.sharp, style: .continuous)
                                        .strokeBorder(.graphite, lineWidth: 1.5)
                                }
                        }
                        .buttonStyle(.borderless)
                        .disabled(activeSession != nil)
                        .opacity(activeSession != nil ? 0.3 : 1)
                        .accessibilityLabel("Empezar \(routine.name)")
                    }
                    .rowSurface()
                }
                .onDelete(perform: deleteRoutines)
            } header: {
                Text("Mis rutinas").labelCaps()
            } footer: {
                Text("Toca una rutina para editarla y asignarle días. ▶ empieza el entreno.").formFooter()
            }
        }
    }

    // MARK: - Historial

    @ViewBuilder
    private var historySections: some View {
        let finished = sessions.filter { !$0.isActive }
        if finished.isEmpty {
            Section {
                RedPoster(text: Quotes.empty, caption: "Tus entrenos terminados aparecen aquí", minHeight: 180)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        } else {
            let grouped = Dictionary(grouping: finished) {
                AppCalendar.calendar.dateInterval(of: .month, for: $0.startedAt)?.start ?? $0.startedAt
            }
            ForEach(grouped.keys.sorted(by: >), id: \.self) { month in
                Section {
                    ForEach(grouped[month] ?? []) { session in
                        NavigationLink(value: GymRoute.session(session)) {
                            SessionRow(session: session, unit: weightUnit)
                        }
                        .rowSurface()
                    }
                } header: {
                    Text(month.formatted(.dateTime.month(.wide).year().locale(AppLocale.spanish))).labelCaps()
                }
            }
        }
    }

    // MARK: - Ejercicios

    @ViewBuilder
    private var exercisesSections: some View {
        let filtered = exercises.filter { exerciseQuery.isEmpty || $0.name.localizedStandardContains(exerciseQuery) }
        Section {
            HStack(spacing: Space.s) {
                Image(systemName: "magnifyingglass").foregroundStyle(.ash)
                TextField("Buscar ejercicio", text: $exerciseQuery)
                    .foregroundStyle(.bone)
            }
            .rowSurface()
        }
        ForEach(MuscleGroup.allCases) { muscle in
            let items = filtered.filter { $0.muscleGroup == muscle }
            if !items.isEmpty {
                Section {
                    ForEach(items) { exercise in
                        NavigationLink(value: GymRoute.exercise(exercise)) {
                            HStack {
                                Text(exercise.name)
                                    .font(.ui(16, .semibold))
                                    .foregroundStyle(.bone)
                                if exercise.isCustom {
                                    Text("Propio").labelCaps(9, .black, color: .brass)
                                }
                                Spacer()
                                Text(exercise.equipment).labelCaps(10, .semibold)
                            }
                        }
                        .rowSurface()
                    }
                } header: {
                    Text(muscle.title).labelCaps()
                }
            }
        }
    }

    // MARK: - Acciones

    private func start(_ routine: Routine?) {
        WorkoutActions.start(routine: routine, unit: weightUnit, in: context)
        Haptics.stamp()
        showSession = true
    }

    private func newRoutine() {
        let routine = Routine(name: "Nueva rutina", colorHex: "FF9500", sortOrder: (routines.map(\.sortOrder).max() ?? -1) + 1)
        context.insert(routine)
        try? context.save()
        scope = .routines
        path.append(.routine(routine))
    }

    private func deleteRoutines(at offsets: IndexSet) {
        for index in offsets {
            context.delete(routines[index])
        }
        try? context.save()
    }
}

/// Fila del historial: fecha, rutina, duración, volumen y récords.
struct SessionRow: View {
    let session: WorkoutSession
    let unit: WeightUnit

    var body: some View {
        let records = WorkoutActions.recordExercises(in: session, unit: unit)
        HStack(alignment: .top, spacing: Space.m) {
            VStack(spacing: 0) {
                Text("\(AppCalendar.calendar.component(.day, from: session.startedAt))")
                    .font(.numeral(32, weight: .thin, relativeTo: .title1))
                    .monospacedDigit()
                    .foregroundStyle(.bone)
                Text(session.startedAt.formatted(.dateTime.weekday(.abbreviated).locale(AppLocale.spanish))
                    .replacingOccurrences(of: ".", with: ""))
                    .labelCaps(10, .semibold)
            }
            .frame(width: 44)

            VStack(alignment: .leading, spacing: Space.xxs) {
                HStack(spacing: Space.xs) {
                    Text(session.routine?.name ?? "Entreno libre")
                        .font(.ui(16, .semibold))
                        .foregroundStyle(.bone)
                    if !records.isEmpty {
                        Text("PR").labelCaps(10, .black, color: .brass)
                    }
                }
                let sets = session.sortedExercises.flatMap(\.completedSets).count
                let minutes = (session.endedAt ?? .now).timeIntervalSince(session.startedAt)
                Text("\(GymMath.duration(minutes)) · \(sets) series · \(GymMath.format(WorkoutActions.volume(of: session, unit: unit), unit: unit))")
                    .labelCaps(10, .semibold)
                    .monospacedDigit()
            }
        }
        .padding(.vertical, Space.xxs)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    GymHomeView()
        .modelContainer(PreviewData.container)
        .preferredColorScheme(.dark)
}
