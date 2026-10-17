import SwiftUI

/// Contador compacto "− 3 +" con etiqueta encima. Pensado para varias columnas en una misma fila
/// de lista (los Stepper del sistema ocupan demasiado ancho).
struct CompactStepper: View {
    let title: String
    @Binding var value: Int
    let range: ClosedRange<Int>
    var step = 1
    let format: (Int) -> String

    init(title: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int = 1,
         format: @escaping (Int) -> String) {
        self.title = title
        self._value = value
        self.range = range
        self.step = step
        self.format = format
    }

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(title).labelCaps(10, .semibold)
            HStack(spacing: 0) {
                button("minus", enabled: value - step >= range.lowerBound) {
                    value = max(range.lowerBound, value - step)
                }
                Text(format(value))
                    .font(.ui(16, .black, relativeTo: .callout))
                    .monospacedDigit()
                    .foregroundStyle(.bone)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .frame(maxWidth: .infinity)
                button("plus", enabled: value + step <= range.upperBound) {
                    value = min(range.upperBound, value + step)
                }
            }
            .frame(height: 36)
            .overlay {
                RoundedRectangle(cornerRadius: Radius.sharp, style: .continuous)
                    .strokeBorder(.graphite, lineWidth: Stroke.hairline)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title): \(format(value))")
        .accessibilityAdjustableAction { direction in
            switch direction {
            case .increment: value = min(range.upperBound, value + step)
            case .decrement: value = max(range.lowerBound, value - step)
            @unknown default: break
            }
        }
    }

    private func button(_ symbol: String, enabled: Bool, action: @escaping () -> Void) -> some View {
        // `.borderless`: en una fila de lista cada botón recibe su propio toque.
        Button {
            action()
            Haptics.tap()
        } label: {
            Image(systemName: symbol)
                .font(.system(size: 12, weight: .black))
                .foregroundStyle(enabled ? Color.bone : .graphite)
                .frame(width: 32, height: 36)
                .contentShape(Rectangle())
        }
        .buttonStyle(.borderless)
        .disabled(!enabled)
    }
}

#Preview {
    HStack(spacing: Space.s) {
        CompactStepper(title: "Series", value: .constant(3), range: 1...10) { "\($0)" }
        CompactStepper(title: "Reps", value: .constant(10), range: 1...50) { "\($0)" }
        CompactStepper(title: "Descanso", value: .constant(90), range: 15...600, step: 15) { "\($0) s" }
    }
    .padding()
    .background(Color.carbon)
}
