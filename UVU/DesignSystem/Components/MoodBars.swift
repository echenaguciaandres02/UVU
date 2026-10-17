import SwiftUI

/// Estado de ánimo como 5 barras de nivel (tipo señal del teléfono). Las llenas van en hueso.
struct MoodBars: View {
    let level: Int
    var height: CGFloat = 18
    var barWidth: CGFloat = 4
    var spacing: CGFloat = 2

    var body: some View {
        HStack(alignment: .bottom, spacing: spacing) {
            ForEach(Mood.range, id: \.self) { index in
                Rectangle()
                    .fill(index <= level ? Color.bone : .graphite)
                    .frame(width: barWidth, height: height * CGFloat(index) / 5)
            }
        }
        .frame(height: height, alignment: .bottom)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Ánimo: \(Mood.title(level)), \(level) de 5")
    }
}

/// Selector de ánimo: cinco barras grandes que se tocan, con la palabra debajo.
struct MoodPicker: View {
    @Binding var level: Int

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .bottom, spacing: Space.xs) {
                ForEach(Mood.range, id: \.self) { index in
                    Button {
                        withAnimation(Motion.quick) { level = index }
                        Haptics.tap()
                    } label: {
                        Rectangle()
                            .fill(index <= level ? Color.bone : .graphite)
                            .frame(height: 16 + CGFloat(index) * 12)
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(Mood.title(index)), \(index) de 5")
                    .accessibilityAddTraits(index == level ? .isSelected : [])
                }
            }
            .frame(height: 76, alignment: .bottom)

            HStack {
                Text(Mood.title(level))
                    .font(.display(28, relativeTo: .title2))
                    .textCase(.uppercase)
                    .foregroundStyle(.bone)
                    .contentTransition(.opacity)
                Spacer()
                Text("\(level)/5")
                    .font(.numeral(22, weight: .thin, relativeTo: .title3))
                    .monospacedDigit()
                    .foregroundStyle(.ash)
            }
        }
        .padding(.vertical, Space.xs)
    }
}

/// Fichas de etiquetas en mayúsculas. `onRemove` muestra una "×" para quitarlas.
struct TagChips: View {
    let tags: [String]
    var selected: String?
    var onTap: ((String) -> Void)?
    var onRemove: ((String) -> Void)?

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.xs) {
                ForEach(tags, id: \.self) { tag in
                    let isSelected = selected.map { JournalStore.sameTag($0, tag) } ?? false
                    HStack(spacing: Space.xxs) {
                        Text("#\(tag)")
                            .font(.ui(12, .black, relativeTo: .caption))
                            .textCase(.uppercase)
                            .tracking(1)
                        if onRemove != nil {
                            Image(systemName: "xmark")
                                .font(.system(size: 9, weight: .black))
                        }
                    }
                    .foregroundStyle(isSelected ? Color.ink : .bone)
                    .padding(.horizontal, Space.s)
                    .padding(.vertical, Space.xs)
                    .background(isSelected ? Color.bone : .clear,
                                in: RoundedRectangle(cornerRadius: Radius.sharp, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: Radius.sharp, style: .continuous)
                            .strokeBorder(isSelected ? Color.bone : .graphite, lineWidth: Stroke.hairline)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if let onRemove { onRemove(tag) } else { onTap?(tag) }
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(onRemove != nil ? "Quitar etiqueta \(tag)" : "Etiqueta \(tag)")
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(.vertical, 2)
        }
        .scrollBounceBehavior(.basedOnSize, axes: .horizontal)
    }
}

#Preview {
    VStack(alignment: .leading, spacing: Space.l) {
        HStack(spacing: Space.m) {
            ForEach(1...5, id: \.self) { MoodBars(level: $0) }
        }
        MoodPicker(level: .constant(4))
        TagChips(tags: ["gym", "tesis", "familia"], selected: "tesis", onTap: { _ in })
    }
    .padding()
    .background(Color.ink)
}
