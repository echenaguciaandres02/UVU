import SwiftUI

/// Selector de vista en mayúsculas con subrayado rojo bajo la opción activa
/// (reemplaza al control segmentado del sistema).
struct ScopeBar<Option: Hashable & Identifiable>: View {
    let options: [Option]
    @Binding var selection: Option
    let title: (Option) -> String
    var badge: (Option) -> Int? = { _ in nil }

    @Namespace private var underline

    var body: some View {
        HStack(spacing: Space.l) {
            ForEach(options) { option in
                let isSelected = option == selection
                Button {
                    withAnimation(Motion.quick) { selection = option }
                    Haptics.tap()
                } label: {
                    VStack(spacing: Space.xs) {
                        HStack(spacing: Space.xxs) {
                            Text(title(option))
                                .font(.ui(13, .black, relativeTo: .footnote))
                                .textCase(.uppercase)
                                .tracking(1.4)
                                .foregroundStyle(isSelected ? Color.bone : .ash)
                            if let count = badge(option), count > 0 {
                                Text("\(count)")
                                    .font(.ui(11, .semibold, relativeTo: .caption))
                                    .monospacedDigit()
                                    .foregroundStyle(.ash)
                            }
                        }
                        ZStack {
                            Rectangle().fill(Color.clear).frame(height: 2)
                            if isSelected {
                                Rectangle()
                                    .fill(.signal)
                                    .frame(height: 2)
                                    .matchedGeometryEffect(id: "underline", in: underline)
                            }
                        }
                    }
                    .fixedSize()
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(title(option))
                .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, Space.xs)
    }
}
