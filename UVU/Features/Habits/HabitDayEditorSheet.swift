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
                    HStack(spacing: Space.s) {
                        SymbolBadge(symbol: habit.symbol, colorHex: habit.colorHex, size: 44)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(habit.name)
                                .font(.ui(17, .semibold, relativeTo: .headline))
                                .textCase(.uppercase)
                                .foregroundStyle(.bone)
                            Text(dayTitle)
                                .labelCaps(11, .semibold)
                        }
                    }
                    .rowSurface()
                }

                if habit.kind == .binary {
                    Section {
                        Button {
                            isDone.toggle()
                            if isDone { Haptics.stamp() } else { Haptics.tap() }
                        } label: {
                            HStack(spacing: Space.m) {
                                HabitCheckbox(progress: isDone ? 1 : 0, size: 44)
                                Text(isDone ? "Hecho" : "Sin hacer")
                                    .font(.display(34, relativeTo: .title))
                                    .textCase(.uppercase)
                                    .foregroundStyle(isDone ? Color.bone : .ash)
                                Spacer()
                            }
                            .padding(.vertical, Space.xs)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isDone ? "Hecho. Toca para desmarcar" : "Sin hacer. Toca para marcar")
                        .rowSurface()
                    }
                } else {
                    quantitySections
                }
            }
            .screenBackground()
            .navigationTitle("REGISTRAR")
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
        .presentationBackground(Color.ink)
    }

    @ViewBuilder
    private var quantitySections: some View {
        Section {
            HStack(alignment: .firstTextBaseline, spacing: Space.xs) {
                TextField("0", text: $amountText)
                    .keyboardType(.decimalPad)
                    .font(.numeral(64))
                    .monospacedDigit()
                    .foregroundStyle(.bone)
                    .focused($amountFocused)
                Text(habit.unit)
                    .labelCaps(13, .semibold)
            }
            QuantityBar(progress: min(amount / max(habit.target, 0.0001), 1))
                .padding(.bottom, Space.xs)
        } footer: {
            Text("Meta: \(habit.goalDescription)")
                .labelCaps(11, .semibold)
        }
        .rowSurface()

        Section {
            HStack(spacing: Space.xs) {
                ForEach(increments, id: \.self) { increment in
                    Button("+\(NumberText.format(increment))") {
                        setAmount(amount + increment)
                    }
                    .buttonStyle(.uvuSecondary)
                }
                Button {
                    setAmount(amount - (increments.first ?? 1))
                } label: {
                    Image(systemName: "minus")
                        .fontWeight(.bold)
                }
                .buttonStyle(.uvuSecondary)
                .accessibilityLabel("Restar")
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        } header: {
            Text("Sumar").labelCaps()
        }

        Section {
            Button("Meta completa") {
                setAmount(habit.target)
            }
            .buttonStyle(.uvuPrimary)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())

            Button(role: .destructive) {
                setAmount(0)
            } label: {
                Text("Borrar registro del día")
                    .labelCaps(12, .semibold, color: .ash)
                    .frame(maxWidth: .infinity)
            }
            .listRowBackground(Color.clear)
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
        return PosterHeader.dateLine(day)
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
        let wasCompleted = HabitActions.isCompleted(habit, on: day)
        HabitActions.setValue(value, for: habit, on: day, in: context)
        if HabitActions.isCompleted(habit, on: day) && !wasCompleted {
            Haptics.stamp()
        }
        dismiss()
    }
}
