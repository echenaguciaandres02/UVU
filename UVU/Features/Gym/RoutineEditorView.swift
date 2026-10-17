import SwiftUI
import SwiftData

/// Editar una rutina: nombre, días de la semana y ejercicios (series, repeticiones y descanso).
/// Los cambios se guardan al momento.
struct RoutineEditorView: View {
    @Bindable var routine: Routine

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @AppStorage("weightUnit") private var weightUnit: WeightUnit = .kg
    @Query private var sessions: [WorkoutSession]

    @State private var showPicker = false
    @State private var showSession = false
    @State private var confirmDelete = false

    var body: some View {
        List {
            Section {
                TextField("Nombre", text: $routine.name)
                    .font(.display(30, relativeTo: .title2))
                    .textCase(.uppercase)
                    .foregroundStyle(.bone)
            }
            .rowSurface()

            Section {
                WeekdayPicker(selection: weekdays)
            } header: {
                Text("Días").labelCaps()
            } footer: {
                Text("Los días asignados aparecen como \"Hoy toca\" en la pantalla de Gym.").formFooter()
            }
            .rowSurface()

            Section {
                ForEach(routine.sortedItems) { item in
                    RoutineItemRow(item: item)
                }
                .onDelete(perform: deleteItems)
                .onMove(perform: moveItems)

                Button {
                    showPicker = true
                } label: {
                    Label("Agregar ejercicio", systemImage: "plus").fontWeight(.semibold)
                }
            } header: {
                Text("Ejercicios · \(routine.sortedItems.count)").labelCaps()
            } footer: {
                Text("Desliza para quitar un ejercicio. Mantén pulsado y arrastra para ordenar.").formFooter()
            }
            .rowSurface()

            Section {
                Button("Empezar esta rutina") { start() }
                    .buttonStyle(.uvuPrimary)
                    .disabled(routine.sortedItems.isEmpty || sessions.contains(where: \.isActive))
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: Space.xs, trailing: 0))
                Button("Borrar rutina") { confirmDelete = true }
                    .buttonStyle(.uvuSecondary)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            }
        }
        .uvuForm()
        .navigationTitle("RUTINA")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(isPresented: $showPicker) {
            ExercisePickerView { exercise in
                addExercise(exercise)
            }
        }
        .fullScreenCover(isPresented: $showSession) {
            LiveSessionView()
        }
        .confirmationDialog("¿Borrar la rutina \"\(routine.name)\"?", isPresented: $confirmDelete,
                            titleVisibility: .visible) {
            Button("Borrar", role: .destructive) {
                context.delete(routine)
                try? context.save()
                dismiss()
            }
        } message: {
            Text("Tu historial de entrenos se conserva.")
        }
        .onDisappear { try? context.save() }
    }

    private var weekdays: Binding<Set<Int>> {
        Binding(
            get: { Set(routine.weekdays) },
            set: { routine.weekdays = $0.sorted(); try? context.save() }
        )
    }

    private func addExercise(_ exercise: Exercise) {
        let item = RoutineExercise(order: (routine.items?.map(\.order).max() ?? -1) + 1)
        context.insert(item)
        item.routine = routine
        item.exercise = exercise
        try? context.save()
    }

    private func deleteItems(at offsets: IndexSet) {
        let items = routine.sortedItems
        for index in offsets { context.delete(items[index]) }
        try? context.save()
    }

    private func moveItems(from source: IndexSet, to destination: Int) {
        var items = routine.sortedItems
        items.move(fromOffsets: source, toOffset: destination)
        for (index, item) in items.enumerated() { item.order = index }
        try? context.save()
    }

    private func start() {
        WorkoutActions.start(routine: routine, unit: weightUnit, in: context)
        Haptics.stamp()
        showSession = true
    }
}

/// Un ejercicio de la rutina con sus objetivos.
private struct RoutineItemRow: View {
    @Bindable var item: RoutineExercise

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(item.exercise?.name ?? "Ejercicio borrado")
                .font(.ui(16, .semibold))
                .foregroundStyle(.bone)
            HStack(spacing: Space.m) {
                Stepper(value: $item.targetSets, in: 1...10) {
                    Text("\(item.targetSets) series").labelCaps(11, .semibold, color: .bone)
                }
                Stepper(value: $item.targetReps, in: 1...50) {
                    Text("\(item.targetReps) reps").labelCaps(11, .semibold, color: .bone)
                }
            }
            Stepper(value: $item.restSeconds, in: 15...600, step: 15) {
                Text("Descanso \(GymMath.duration(TimeInterval(item.restSeconds)))").labelCaps(11, .semibold)
            }
        }
        .padding(.vertical, Space.xxs)
    }
}

/// Elegir un ejercicio de la biblioteca (con búsqueda), o crear uno propio.
struct ExercisePickerView: View {
    var onPick: (Exercise) -> Void

    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var query = ""
    @State private var showNew = false

    var body: some View {
        NavigationStack {
            List {
                ForEach(MuscleGroup.allCases) { muscle in
                    let items = exercises.filter {
                        $0.muscleGroup == muscle && (query.isEmpty || $0.name.localizedStandardContains(query))
                    }
                    if !items.isEmpty {
                        Section {
                            ForEach(items) { exercise in
                                Button {
                                    onPick(exercise)
                                    Haptics.tap()
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text(exercise.name).font(.ui(16, .semibold)).foregroundStyle(.bone)
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
            .screenBackground()
            .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Buscar ejercicio")
            .navigationTitle("EJERCICIO")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Nuevo") { showNew = true }
                }
            }
            .sheet(isPresented: $showNew) {
                ExerciseFormView { created in
                    onPick(created)
                    dismiss()
                }
            }
        }
        .presentationBackground(Color.ink)
    }
}

/// Crear un ejercicio propio: nombre, músculo y equipo.
struct ExerciseFormView: View {
    var onCreate: ((Exercise) -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var muscle: MuscleGroup = .chest
    @State private var equipment = ""

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Nombre del ejercicio", text: $name)
                        .font(.ui(20, .semibold, relativeTo: .title3))
                    Picker("Músculo", selection: $muscle) {
                        ForEach(MuscleGroup.allCases) { muscle in
                            Text(muscle.title).tag(muscle)
                        }
                    }
                    TextField("Equipo (barra, mancuernas…)", text: $equipment)
                }
                .rowSurface()
            }
            .uvuForm()
            .navigationTitle("NUEVO EJERCICIO")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .fontWeight(.semibold)
                        .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationBackground(Color.ink)
    }

    private func save() {
        let exercise = Exercise(name: name.trimmingCharacters(in: .whitespaces), muscle: muscle,
                                equipment: equipment.trimmingCharacters(in: .whitespaces), isCustom: true)
        context.insert(exercise)
        try? context.save()
        onCreate?(exercise)
        dismiss()
    }
}
