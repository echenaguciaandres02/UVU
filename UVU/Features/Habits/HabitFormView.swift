import SwiftUI
import SwiftData

/// Crear un hábito nuevo (`habit == nil`) o editar uno existente.
struct HabitFormView: View {
    let habit: Habit?
    var onArchive: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Habit.sortOrder) private var allHabits: [Habit]

    @State private var name = ""
    @State private var symbol = "checkmark.circle.fill"
    @State private var colorHex = "34C759"
    @State private var kind: HabitKind = .binary
    @State private var targetText = ""
    @State private var unit = ""
    @State private var frequency: HabitFrequency = .daily
    @State private var weekdays: Set<Int> = [2, 3, 4, 5, 6]
    @State private var timesPerWeek = 3
    @State private var hasReminder = false
    @State private var reminderTime = AppCalendar.calendar.date(from: DateComponents(hour: 9, minute: 0)) ?? .now
    @State private var didLoad = false
    @State private var confirmArchive = false

    init(habit: Habit?, onArchive: (() -> Void)? = nil) {
        self.habit = habit
        self.onArchive = onArchive
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Nombre del hábito", text: $name)
                }

                Section("Apariencia") {
                    NavigationLink {
                        SymbolPickerView(selection: $symbol, colorHex: colorHex)
                    } label: {
                        HStack {
                            Text("Ícono")
                            Spacer()
                            SymbolBadge(symbol: symbol, colorHex: colorHex, size: 28)
                        }
                    }
                    ColorPaletteView(selection: $colorHex)
                }

                Section {
                    Picker("Tipo", selection: $kind) {
                        ForEach(HabitKind.allCases) { kind in
                            Text(kind.title).tag(kind)
                        }
                    }
                    .pickerStyle(.segmented)

                    if kind == .quantity {
                        HStack {
                            Text("Meta diaria")
                            Spacer()
                            TextField("8", text: $targetText)
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(maxWidth: 120)
                        }
                        HStack {
                            Text("Unidad")
                            Spacer()
                            TextField("vasos, min, g…", text: $unit)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                } header: {
                    Text("Tipo")
                } footer: {
                    Text(kind == .binary
                         ? "Se marca con un toque: hecho o no hecho."
                         : "Registras una cantidad y se cumple al llegar a la meta.")
                }

                Section("Frecuencia") {
                    Picker("Frecuencia", selection: $frequency) {
                        ForEach(HabitFrequency.allCases) { frequency in
                            Text(frequency.title).tag(frequency)
                        }
                    }
                    switch frequency {
                    case .daily:
                        EmptyView()
                    case .specificDays:
                        WeekdayPicker(selection: $weekdays)
                    case .timesPerWeek:
                        Stepper(timesPerWeek == 1 ? "1 vez por semana" : "\(timesPerWeek) veces por semana",
                                value: $timesPerWeek, in: 1...7)
                    }
                }

                Section {
                    Toggle("Recordatorio", isOn: $hasReminder.animation())
                    if hasReminder {
                        DatePicker("Hora", selection: $reminderTime, displayedComponents: .hourAndMinute)
                    }
                } footer: {
                    Text("Recibirás una notificación a esa hora los días que toque el hábito.")
                }

                if habit != nil {
                    Section {
                        Button("Archivar hábito") { confirmArchive = true }
                    } footer: {
                        Text("Deja de aparecer pero conserva su historial. Puedes restaurarlo o eliminarlo desde Hábitos → ⋯ → Archivados.")
                    }
                }
            }
            .navigationTitle(habit == nil ? "Nuevo hábito" : "Editar hábito")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .confirmationDialog("¿Archivar este hábito?", isPresented: $confirmArchive, titleVisibility: .visible) {
                Button("Archivar") { archive() }
            }
            .onAppear(perform: load)
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var isValid: Bool {
        guard !trimmedName.isEmpty else { return false }
        if kind == .quantity {
            guard let target = NumberText.parse(targetText), target > 0 else { return false }
        }
        if frequency == .specificDays && weekdays.isEmpty { return false }
        return true
    }

    private func load() {
        guard !didLoad else { return }
        didLoad = true
        guard let habit else { return }
        name = habit.name
        symbol = habit.symbol
        colorHex = habit.colorHex
        kind = habit.kind
        targetText = habit.kind == .quantity ? NumberText.format(habit.target) : ""
        unit = habit.unit
        frequency = habit.frequency
        if !habit.weekdays.isEmpty { weekdays = Set(habit.weekdays) }
        timesPerWeek = habit.timesPerWeek
        if let hour = habit.reminderHour, let minute = habit.reminderMinute {
            hasReminder = true
            reminderTime = AppCalendar.calendar.date(from: DateComponents(hour: hour, minute: minute)) ?? reminderTime
        }
    }

    private func save() {
        let target: Habit
        if let habit {
            target = habit
        } else {
            let nextOrder = (allHabits.map(\.sortOrder).max() ?? -1) + 1
            target = Habit(name: trimmedName, symbol: symbol, colorHex: colorHex, sortOrder: nextOrder)
            context.insert(target)
        }

        target.name = trimmedName
        target.symbol = symbol
        target.colorHex = colorHex
        target.kind = kind
        target.target = kind == .quantity ? (NumberText.parse(targetText) ?? 1) : 1
        target.unit = kind == .quantity ? unit.trimmingCharacters(in: .whitespaces) : ""
        target.frequency = frequency
        target.weekdays = frequency == .specificDays ? weekdays.sorted() : []
        target.timesPerWeek = timesPerWeek
        if hasReminder {
            let components = AppCalendar.calendar.dateComponents([.hour, .minute], from: reminderTime)
            target.reminderHour = components.hour
            target.reminderMinute = components.minute
        } else {
            target.reminderHour = nil
            target.reminderMinute = nil
        }

        try? context.save()
        Task { await NotificationService.scheduleHabitReminder(for: target) }
        dismiss()
    }

    private func archive() {
        guard let habit else { return }
        habit.isArchived = true
        try? context.save()
        NotificationService.removeHabitReminders(for: habit.id)
        dismiss()
        onArchive?()
    }
}

#Preview {
    HabitFormView(habit: nil)
        .modelContainer(PreviewData.container)
}
