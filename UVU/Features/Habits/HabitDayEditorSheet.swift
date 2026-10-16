import SwiftUI
import SwiftData

/// Registrar o corregir un hábito en un día concreto (hoy o un día pasado).
struct HabitDayEditorSheet: View {
    let habit: Habit
    let day: Date

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var isDone = false
    @State private var amountText = ""
    @FocusState private var amountFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack(spacing: 12) {
                        SymbolBadge(symbol: habit.symbol, colorHex: habit.colorHex, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(habit.name)
                                .font(.headline)
                            Text(dayTitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if habit.kind == .binary {
                    Section {
                        Toggle("Cumplido", isOn: $isDone)
                    }
                } else {
                    quantitySections
                }
            }
            .navigationTitle("Registrar")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") { save() }
                        .fontWeight(.semibold)
                }
            }
            .onAppear(perform: load)
        }
        .presentationDetents([.medium, .large])
    }

    @ViewBuilder
    private var quantitySections: some View {
        Section {
            HStack(alignment: .firstTextBaseline) {
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .focused($amountFocused)
                Text(habit.unit)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: min(amount / max(habit.target, 0.0001), 1))
                .tint(Color(hex: habit.colorHex))
        } footer: {
            Text("Meta: \(habit.goalDescription)")
        }

        Section("Sumar") {
            HStack(spacing: 10) {
                ForEach(increments, id: \.self) { increment in
                    Button("+\(NumberText.format(increment))") {
                        setAmount(amount + increment)
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
                Button {
                    setAmount(amount - (increments.first ?? 1))
                } label: {
                    Image(systemName: "minus")
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Restar")
            }
        }

        Section {
            Button("Marcar meta completa") {
                setAmount(habit.target)
            }
            Button("Borrar registro del día", role: .destructive) {
                setAmount(0)
            }
        }
    }

    private var amount: Double {
        NumberText.parse(amountText) ?? 0
    }

    /// Botones de suma rápida según el tamaño de la meta.
    private var increments: [Double] {
        switch habit.target {
        case ...10: return [1, 2]
        case ...60: return [5, 10, 15]
        default: return [10, 25, 50]
        }
    }

    private var dayTitle: String {
        if AppCalendar.calendar.isDateInToday(day) { return "Hoy" }
        if AppCalendar.calendar.isDateInYesterday(day) { return "Ayer" }
        return day.formatted(.dateTime.weekday(.wide).day().month(.wide).locale(AppLocale.spanish)).capitalizedFirst
    }

    private func setAmount(_ value: Double) {
        amountText = NumberText.format(max(0, value))
        Haptics.tap()
    }

    private func load() {
        let value = HabitActions.value(for: habit, on: day)
        isDone = value >= 1
        amountText = value > 0 ? NumberText.format(value) : ""
    }

    private func save() {
        let value = habit.kind == .binary ? (isDone ? 1 : 0) : amount
        HabitActions.setValue(value, for: habit, on: day, in: context)
        if HabitActions.isCompleted(habit, on: day) {
            Haptics.success()
        }
        dismiss()
    }
}
