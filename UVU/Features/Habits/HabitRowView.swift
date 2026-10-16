import SwiftUI
import SwiftData

/// Fila de un hábito con el checkbox para marcarlo en `day`.
/// Sí/no: un toque marca o desmarca (se "estampa" en rojo). Cuantitativo: abre el registro de cantidad.
struct HabitRowView: View {
    let habit: Habit
    let day: Date
    var onQuantityTap: () -> Void

    @Environment(\.modelContext) private var context

    var body: some View {
        let evaluator = HabitEvaluator(habit: habit)
        let value = evaluator.value(on: day)
        let isDone = evaluator.isCompleted(value)
        let streak = evaluator.currentStreak()
        let progress = evaluator.progress(on: day)

        HStack(spacing: Space.s) {
            SymbolBadge(symbol: habit.symbol, colorHex: habit.colorHex, size: 36)

            VStack(alignment: .leading, spacing: Space.xxs) {
                Text(habit.name)
                    .font(.ui(16, .semibold, relativeTo: .body))
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .foregroundStyle(isDone ? Color.ash : .bone)
                    .lineLimit(2)
                HStack(spacing: Space.xs) {
                    Text(subtitle(value: value, isDone: isDone))
                    if streak > 0 {
                        HStack(spacing: 2) {
                            Image(systemName: "flame.fill")
                            Text("\(streak)")
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("Racha de \(streak) \(evaluator.streakUnit)")
                    }
                }
                .labelCaps(11, .semibold)
                .monospacedDigit()

                if habit.kind == .quantity {
                    QuantityBar(progress: progress)
                        .padding(.top, 2)
                }
            }

            Spacer(minLength: Space.xs)

            Button {
                if habit.kind == .binary {
                    if HabitActions.toggle(habit, on: day, in: context) {
                        Haptics.stamp()
                    } else {
                        Haptics.tap()
                    }
                } else {
                    Haptics.tap()
                    onQuantityTap()
                }
            } label: {
                HabitCheckbox(progress: habit.kind == .binary ? (isDone ? 1 : 0) : progress)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(accessibilityLabel(isDone: isDone))
            .accessibilityAddTraits(isDone ? .isSelected : [])
        }
        .padding(.vertical, Space.xxs)
    }

    private func subtitle(value: Double, isDone: Bool) -> String {
        switch habit.kind {
        case .binary:
            return isDone ? "Hecho" : habit.frequencyDescription
        case .quantity:
            return "\(NumberText.format(value)) / \(NumberText.format(habit.target)) \(habit.unit)"
        }
    }

    private func accessibilityLabel(isDone: Bool) -> String {
        if habit.kind == .binary {
            return isDone ? "Desmarcar \(habit.name)" : "Marcar \(habit.name)"
        }
        return "Registrar \(habit.name)"
    }
}
