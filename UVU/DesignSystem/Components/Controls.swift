import SwiftUI

/// Checkbox cuadrado de hábito.
/// - Vacío: borde `graphite`.
/// - Parcial (cuantitativos): se llena de abajo hacia arriba en `signalDeep`.
/// - Completo: cuadro `signal` lleno con check `ink`. Al completarse se "estampa" (1,15 → 1,0).
struct HabitCheckbox: View {
    /// 0 = vacío, 0…1 = parcial, ≥ 1 = completo.
    let progress: Double
    var size: CGFloat = 30

    @State private var scale: CGFloat = 1

    private var isComplete: Bool { progress >= 1 }

    var body: some View {
        let shape = RoundedRectangle(cornerRadius: Radius.sharp, style: .continuous)
        ZStack(alignment: .bottom) {
            if isComplete {
                shape.fill(.signal)
            } else if progress > 0 {
                Rectangle()
                    .fill(.signalDeep)
                    .frame(height: size * min(progress, 1))
                    .clipShape(shape)
            }
            shape.strokeBorder(isComplete ? Color.signal : .graphite, lineWidth: 1.5)
            if isComplete {
                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.5, weight: .black))
                    .foregroundStyle(.ink)
                    .frame(maxHeight: .infinity)
            }
        }
        .frame(width: size, height: size)
        .scaleEffect(scale)
        .onChange(of: isComplete) { _, nowComplete in
            guard nowComplete else { return }
            withAnimation(.snappy(duration: 0.07)) {
                scale = 1.15
            } completion: {
                withAnimation(Motion.stamp) { scale = 1 }
            }
        }
    }
}

/// Barra de progreso recta. En las filas va en hueso (el rojo queda para el checkbox);
/// `accent: true` la pinta en rojo, para el único progreso dominante de una pantalla.
struct QuantityBar: View {
    let progress: Double
    var accent = false

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Rectangle().fill(.graphite)
                Rectangle()
                    .fill(fill)
                    .frame(width: proxy.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 3)
        .accessibilityHidden(true)
    }

    private var fill: Color {
        if accent { return progress >= 1 ? .signal : .signalDeep }
        return progress >= 1 ? .bone : .ash
    }
}

/// Número enorme ultraligero con la etiqueta "DÍAS SEGUIDOS". Si es récord, la etiqueta pasa a `brass`.
struct StreakCounter: View {
    let value: Int
    var unit: String = "días"
    var isRecord = false
    var size: CGFloat = 96

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("\(value)")
                .font(.numeral(size))
                .monospacedDigit()
                .foregroundStyle(.bone)
                .contentTransition(.numericText(value: Double(value)))
            HStack(spacing: Space.xs) {
                Text("\(unit) seguidos".uppercased())
                    .labelCaps(12, .semibold, color: isRecord ? .brass : .ash)
                if isRecord && value > 0 {
                    Text("Récord")
                        .labelCaps(12, .black, color: .brass)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Racha: \(value) \(unit) seguidos\(isRecord && value > 0 ? ", récord" : "")")
    }
}

/// Botón rectangular de UVU.
/// - Primario: fondo `signal`, texto `ink` en Inter Black (≥ 17 pt, contraste de texto grande).
/// - Secundario: contorno `bone` de 1 pt.
struct UVUButtonStyle: ButtonStyle {
    enum Kind {
        case primary
        case secondary
    }

    let kind: Kind

    func makeBody(configuration: Configuration) -> some View {
        UVUButtonBody(kind: kind, configuration: configuration)
    }

    private struct UVUButtonBody: View {
        let kind: Kind
        let configuration: ButtonStyleConfiguration
        @Environment(\.isEnabled) private var isEnabled

        var body: some View {
            let shape = RoundedRectangle(cornerRadius: Radius.card, style: .continuous)
            configuration.label
                .font(.ui(17, .black, relativeTo: .headline))
                .textCase(.uppercase)
                .tracking(1.2)
                .foregroundStyle(foreground)
                .frame(maxWidth: .infinity)
                .padding(.vertical, Space.m)
                .padding(.horizontal, Space.l)
                .background(background, in: shape)
                .overlay {
                    if kind == .secondary {
                        shape.strokeBorder(.bone, lineWidth: Stroke.hairline)
                    }
                }
                .contentShape(shape)
                .opacity(isEnabled ? 1 : 0.4)
                .animation(Motion.quick, value: configuration.isPressed)
        }

        private var foreground: Color {
            switch kind {
            case .primary: return configuration.isPressed ? .bone : .ink
            case .secondary: return .bone
            }
        }

        private var background: Color {
            switch kind {
            case .primary: return configuration.isPressed ? .signalDeep : .signal
            case .secondary: return configuration.isPressed ? .carbon : .clear
            }
        }
    }
}

extension ButtonStyle where Self == UVUButtonStyle {
    static var uvuPrimary: UVUButtonStyle { UVUButtonStyle(kind: .primary) }
    static var uvuSecondary: UVUButtonStyle { UVUButtonStyle(kind: .secondary) }
}

#Preview {
    VStack(alignment: .leading, spacing: Space.l) {
        HStack(spacing: Space.m) {
            HabitCheckbox(progress: 0)
            HabitCheckbox(progress: 0.4)
            HabitCheckbox(progress: 1)
        }
        QuantityBar(progress: 0.6)
        StreakCounter(value: 21, isRecord: true)
        Button("Empezar") {}.buttonStyle(.uvuPrimary)
        Button("Editar") {}.buttonStyle(.uvuSecondary)
    }
    .padding()
    .background(Color.ink)
}
