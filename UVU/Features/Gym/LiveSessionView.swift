import SwiftUI
import SwiftData

/// Sesión en vivo, a pantalla completa. Muestra la sesión sin terminar (si no hay, se cierra).
struct LiveSessionView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<WorkoutSession> { $0.endedAt == nil }, sort: \WorkoutSession.startedAt, order: .reverse)
    private var active: [WorkoutSession]
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg

    @State private var timer = RestTimer.shared
    @State private var showPicker = false
    @State private var confirmFinish = false
    @State private var confirmDiscard = false
    @State private var summary: WorkoutSummary?

    var body: some View {
        NavigationStack {
            Group {
                if let session = active.first {
                    sessionList(session)
                } else if summary == nil {
                    Color.ink.onAppear { dismiss() }
                } else {
                    Color.ink
                }
            }
            .background(Color.ink.ignoresSafeArea())
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                        .accessibilityHint("La sesión sigue en curso")
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Terminar") { confirmFinish = true }
                        .fontWeight(.semibold)
                        .disabled(active.isEmpty)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if timer.isRunning {
                    RestTimerBar(timer: timer)
                }
            }
            .sheet(isPresented: $showPicker) {
                ExercisePickerView { exercise in
                    if let session = active.first {
                        WorkoutActions.addExercise(exercise, to: session, unit: weightUnit, in: context)
                    }
                }
            }
            .confirmationDialog("¿Terminar el entreno?", isPresented: $confirmFinish, titleVisibility: .visible) {
                Button("Terminar entreno") { finish() }
                Button("Descartar sesión", role: .destructive) { confirmDiscard = true }
            } message: {
                Text("Se guardan solo las series marcadas como hechas.")
            }
            .confirmationDialog("¿Descartar esta sesión?", isPresented: $confirmDiscard, titleVisibility: .visible) {
                Button("Descartar", role: .destructive) {
                    if let session = active.first { WorkoutActions.discard(session, in: context) }
                    timer.stop()
                    dismiss()
                }
            } message: {
                Text("No se guarda nada de este entreno.")
            }
            .overlay {
                if let summary {
                    WorkoutSummaryView(summary: summary) { dismiss() }
                        .transition(.opacity)
                }
            }
        }
    }

    private func sessionList(_ session: WorkoutSession) -> some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: Space.xxs) {
                    Text(session.routine?.name ?? "Entreno libre").posterTitle(44, relativeTo: .title)
                    TimelineView(.periodic(from: .now, by: 1)) { timeline in
                        HStack(spacing: Space.s) {
                            Text(GymMath.duration(timeline.date.timeIntervalSince(session.startedAt)))
                                .font(.numeral(28, weight: .thin, relativeTo: .title2))
                                .monospacedDigit()
                                .foregroundStyle(.bone)
                            let done = session.sortedExercises.flatMap(\.completedSets).count
                            let total = session.sortedExercises.flatMap(\.sortedSets).count
                            Text("\(done)/\(total) series").labelCaps(11, .semibold)
                        }
                    }
                }
                .listRowBackground(Color.clear)
            }

            ForEach(session.sortedExercises) { item in
                ExerciseBlock(item: item, unit: weightUnit) { set in
                    setCompleted(set, in: item)
                }
            }

            Section {
                Button {
                    showPicker = true
                } label: {
                    Label("Agregar ejercicio", systemImage: "plus").fontWeight(.semibold)
                }
                .buttonStyle(.uvuSecondary)
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())
            }
        }
        .uvuForm()
        .scrollDismissesKeyboard(.interactively)
    }

    private func setCompleted(_ set: WorkoutSet, in item: SessionExercise) {
        guard set.isCompleted else {
            Haptics.tap()
            return
        }
        Haptics.stamp()
        let next = nextPending(after: item)
        timer.start(seconds: item.restSeconds,
                    exerciseName: next?.exercise ?? item.exercise?.name ?? "",
                    nextSet: next?.label ?? "Última serie hecha",
                    workoutName: item.session?.routine?.name ?? "Entreno libre")
    }

    /// Siguiente serie sin hacer: primero en este ejercicio, luego en los siguientes.
    private func nextPending(after item: SessionExercise) -> (exercise: String, label: String)? {
        guard let session = item.session else { return nil }
        let exercises = session.sortedExercises
        let startIndex = exercises.firstIndex { $0.id == item.id } ?? 0
        for candidate in exercises[startIndex...] {
            let sets = candidate.sortedSets
            if let index = sets.firstIndex(where: { !$0.isCompleted }) {
                return (candidate.exercise?.name ?? "Ejercicio", "Serie \(index + 1) de \(sets.count)")
            }
        }
        return nil
    }

    private func finish() {
        guard let session = active.first else { return }
        timer.stop()
        let snapshot = WorkoutSummary(session: session, unit: weightUnit)
        if WorkoutActions.finish(session, in: context) {
            Haptics.success()
            withAnimation(Motion.quick) {
                summary = WorkoutSummary(session: session, unit: weightUnit, fallback: snapshot)
            }
        } else {
            dismiss()
        }
    }
}

/// Un ejercicio de la sesión: lo de la última vez y sus series.
private struct ExerciseBlock: View {
    let item: SessionExercise
    let unit: WeightUnit
    var onToggle: (WorkoutSet) -> Void

    @Environment(\.modelContext) private var context

    var body: some View {
        Section {
            ForEach(Array(item.sortedSets.enumerated()), id: \.element.id) { index, set in
                SetRow(set: set, index: index + 1) {
                    WorkoutActions.toggle(set, in: context)
                    onToggle(set)
                }
            }
            .onDelete { offsets in
                let sets = item.sortedSets
                for index in offsets { context.delete(sets[index]) }
                try? context.save()
            }
            Button {
                WorkoutActions.addSet(to: item, unit: unit, in: context)
            } label: {
                Label("Serie", systemImage: "plus").font(.ui(14, .semibold))
            }
        } header: {
            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(item.exercise?.name ?? "Ejercicio")
                    .font(.ui(17, .black, relativeTo: .headline))
                    .textCase(.uppercase)
                    .tracking(0.8)
                    .foregroundStyle(.bone)
                if let exercise = item.exercise,
                   let last = WorkoutActions.describe(WorkoutActions.lastPerformance(of: exercise, before: item.session,
                                                                                    in: context)) {
                    Text("Última vez: \(last)").labelCaps(10, .semibold)
                } else {
                    Text("Primera vez").labelCaps(10, .semibold)
                }
            }
            .padding(.top, Space.s)
        }
        .rowSurface()
    }
}

/// Una serie: número, peso, unidad, repeticiones, RPE y check.
private struct SetRow: View {
    @Bindable var set: WorkoutSet
    let index: Int
    var onToggle: () -> Void

    private static let rpeOptions: [Double] = [6, 6.5, 7, 7.5, 8, 8.5, 9, 9.5, 10]

    var body: some View {
        HStack(spacing: Space.s) {
            Text("\(index)")
                .font(.numeral(20, weight: .thin, relativeTo: .body))
                .monospacedDigit()
                .foregroundStyle(.ash)
                .frame(width: 22)

            TextField("0", value: $set.weight, format: .number.locale(AppLocale.spanish).precision(.fractionLength(0...2)))
                .keyboardType(.decimalPad)
                .font(.ui(18, .semibold).monospacedDigit())
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 52)
                .accessibilityLabel("Peso de la serie \(index)")

            Button(set.unit.rawValue) {
                set.unit = set.unit == .kg ? .lb : .kg
            }
            .font(.ui(12, .black))
            .textCase(.uppercase)
            .foregroundStyle(.ash)
            .buttonStyle(.borderless)
            .accessibilityLabel("Unidad: \(set.unit.rawValue). Toca para cambiar")

            Text("×").foregroundStyle(.ash)

            TextField("0", value: $set.reps, format: .number)
                .keyboardType(.numberPad)
                .font(.ui(18, .semibold).monospacedDigit())
                .multilineTextAlignment(.trailing)
                .frame(minWidth: 36)
                .accessibilityLabel("Repeticiones de la serie \(index)")

            Menu {
                Button("Sin RPE") { set.rpe = nil }
                ForEach(Self.rpeOptions, id: \.self) { value in
                    Button("RPE \(NumberText.format(value))") { set.rpe = value }
                }
            } label: {
                Text(set.rpe.map { "@\(NumberText.format($0))" } ?? "RPE")
                    .font(.ui(12, .black))
                    .foregroundStyle(set.rpe == nil ? Color.ash : .bone)
                    .frame(minWidth: 36)
            }
            .accessibilityLabel(set.rpe.map { "RPE \(NumberText.format($0))" } ?? "Sin RPE")

            Spacer(minLength: 0)

            Button(action: onToggle) {
                HabitCheckbox(progress: set.isCompleted ? 1 : 0, size: 30)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(set.isCompleted ? "Desmarcar serie \(index)" : "Marcar serie \(index) como hecha")
        }
        .opacity(set.isCompleted ? 0.75 : 1)
    }
}

/// Barra fija abajo con la cuenta atrás del descanso.
private struct RestTimerBar: View {
    let timer: RestTimer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { timeline in
            let remaining = timer.remaining(at: timeline.date)
            HStack(spacing: Space.m) {
                VStack(alignment: .leading, spacing: 0) {
                    // Inter Black 15: texto "grande" para el contraste negro sobre rojo.
                    Text("Descanso")
                        .font(.ui(15, .black, relativeTo: .subheadline))
                        .textCase(.uppercase)
                        .tracking(1.4)
                        .foregroundStyle(.ink)
                    Text(GymMath.duration(remaining.rounded(.up)))
                        .font(.numeral(40, weight: .light, relativeTo: .title1))
                        .monospacedDigit()
                        .foregroundStyle(.ink)
                }
                Spacer()
                timerButton("−15") { timer.adjust(by: -15) }
                timerButton("+15") { timer.adjust(by: 15) }
                timerButton("Saltar") { timer.stop() }
            }
            .padding(.horizontal, Space.m)
            .padding(.vertical, Space.s)
            .background(.signal)
            .grain(.poster)
            .onChange(of: remaining <= 0) { _, finished in
                if finished, timer.finishIfElapsed() {
                    Haptics.success()
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func timerButton(_ title: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.ui(15, .black, relativeTo: .subheadline))
                .textCase(.uppercase)
                .foregroundStyle(.ink)
                .padding(.horizontal, Space.s)
                .padding(.vertical, Space.xs)
                .overlay {
                    RoundedRectangle(cornerRadius: Radius.sharp, style: .continuous)
                        .strokeBorder(Color.ink, lineWidth: 1.5)
                }
        }
        .buttonStyle(.plain)
    }
}

/// Resumen al terminar.
struct WorkoutSummary {
    let title: String
    let duration: TimeInterval
    let sets: Int
    let volume: Double
    let unit: WeightUnit
    let records: [String]

    @MainActor
    init(session: WorkoutSession, unit: WeightUnit, fallback: WorkoutSummary? = nil) {
        title = session.routine?.name ?? "Entreno libre"
        duration = (session.endedAt ?? .now).timeIntervalSince(session.startedAt)
        let completed = session.sortedExercises.flatMap(\.completedSets)
        sets = completed.isEmpty ? (fallback?.sets ?? 0) : completed.count
        volume = completed.isEmpty ? (fallback?.volume ?? 0) : WorkoutActions.volume(of: session, unit: unit)
        self.unit = unit
        records = session.endedAt == nil ? [] : WorkoutActions.recordExercises(in: session, unit: unit)
    }
}

private struct WorkoutSummaryView: View {
    let summary: WorkoutSummary
    var onDone: () -> Void

    var body: some View {
        ZStack {
            Color.signal.ignoresSafeArea().grain(.poster)
            VStack(alignment: .leading, spacing: Space.l) {
                Spacer()
                Text("Entreno terminado.")
                    .font(.display(72, relativeTo: .largeTitle))
                    .textCase(.uppercase)
                    .tracking(-1)
                    .foregroundStyle(.ink)
                    .minimumScaleFactor(0.5)
                VStack(alignment: .leading, spacing: Space.xs) {
                    summaryLine("Duración", GymMath.duration(summary.duration))
                    summaryLine("Series", "\(summary.sets)")
                    summaryLine("Volumen", GymMath.format(summary.volume, unit: summary.unit))
                    if !summary.records.isEmpty {
                        summaryLine("Récords", summary.records.joined(separator: ", "))
                    }
                }
                Text("Hábito \"Ejercicio\" marcado.")
                    .font(.ui(15, .black, relativeTo: .subheadline))
                    .textCase(.uppercase)
                    .foregroundStyle(.ink)
                TapeLabel(text: "DO.")
                Spacer()
                Button(action: onDone) {
                    Text("Listo")
                        .font(.ui(17, .black, relativeTo: .headline))
                        .textCase(.uppercase)
                        .tracking(1.2)
                        .foregroundStyle(.bone)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, Space.m)
                        .background(.ink, in: RoundedRectangle(cornerRadius: Radius.card, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .padding(Space.l)
        }
        .accessibilityElement(children: .contain)
    }

    private func summaryLine(_ label: String, _ value: String) -> some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(.ui(15, .black, relativeTo: .subheadline))
                .textCase(.uppercase)
                .tracking(1.4)
                .foregroundStyle(.ink)
            Spacer()
            Text(value)
                .font(.ui(20, .black, relativeTo: .title3))
                .monospacedDigit()
                .foregroundStyle(.ink)
                .multilineTextAlignment(.trailing)
        }
    }
}
