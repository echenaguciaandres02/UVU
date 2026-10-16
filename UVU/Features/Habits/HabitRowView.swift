import SwiftUI
import SwiftData

/// Fila de un hábito con el botón para marcarlo en `day`.
/// Sí/no: un toque marca o desmarca. Cuantitativo: abre el registro de cantidad.
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

        HStack(spacing: 12) {
            SymbolBadge(symbol: habit.symbol, colorHex: habit.colorHex, size: 36)

            VStack(alignment: .leading, spacing: 2) {
                Text(habit.name)
                HStack(spacing: 8) {
                    Text(subtitle(value: value, isDone: isDone))
                    if streak > 0 {
                        Label("\(streak)", systemImage: "flame.fill")
                            .labelStyle(.titleAndIcon)
                            .foregroundStyle(.orange)
                            .accessibilityLabel("Racha de \(streak) \(evaluator.streakUnit)")
                    }
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Button {
                if habit.kind == .binary {
                    if HabitActions.toggle(habit, on: day, in: context) {
                        Haptics.success()
                    } else {
                        Haptics.tap()
                    }
                } else {
                    Haptics.tap()
                    onQuantityTap()
                }
            } label: {
                control(value: value, isDone: isDone, progress: evaluator.progress(on: day))
            }
            .buttonStyle(.borderless)
            .accessibilityLabel(accessibilityLabel(isDone: isDone))
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func control(value: Double, isDone: Bool, progress: Double) -> some View {
        let color = Color(hex: habit.colorHex)
        if habit.kind == .binary {
            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 30))
                .foregroundStyle(isDone ? color : Color.secondary)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 44, height: 44)
        } else {
            ProgressRing(progress: progress, color: color)
                .frame(width: 30, height: 30)
                .frame(width: 44, height: 44)
        }
    }

    private func subtitle(value: Double, isDone: Bool) -> String {
        switch habit.kind {
        case .binary:
            return isDone ? "Cumplido" : habit.frequencyDescription
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
