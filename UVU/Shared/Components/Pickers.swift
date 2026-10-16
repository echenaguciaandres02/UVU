import SwiftUI

/// Paleta de colores para elegir el color de un hábito, lista o rutina (se muestran apagados,
/// como se verán en la app).
struct ColorPaletteView: View {
    @Binding var selection: String

    private let columns = Array(repeating: GridItem(.flexible(), spacing: Space.s), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: Space.s) {
            ForEach(AppPalette.colors, id: \.self) { hex in
                let isSelected = selection == hex
                Button {
                    selection = hex
                } label: {
                    RoundedRectangle(cornerRadius: Radius.sharp, style: .continuous)
                        .fill(Color.muted(hex: hex))
                        .frame(height: 34)
                        .overlay {
                            RoundedRectangle(cornerRadius: Radius.sharp, style: .continuous)
                                .strokeBorder(isSelected ? Color.bone : .clear, lineWidth: 2)
                                .padding(-4)
                        }
                        .overlay {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 13, weight: .black))
                                    .foregroundStyle(.ink)
                            }
                        }
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Color")
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, Space.xs)
    }
}

/// Selector de días de la semana (L M X J V S D).
struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        HStack(spacing: Space.xxs) {
            ForEach(AppCalendar.orderedWeekdays, id: \.self) { weekday in
                let isOn = selection.contains(weekday)
                let shape = RoundedRectangle(cornerRadius: Radius.sharp, style: .continuous)
                Button {
                    withAnimation(Motion.quick) {
                        if isOn {
                            selection.remove(weekday)
                        } else {
                            selection.insert(weekday)
                        }
                    }
                } label: {
                    Text(AppCalendar.veryShortWeekdayName(weekday))
                        .font(.ui(16, .black, relativeTo: .callout))
                        .textCase(.uppercase)
                        .frame(maxWidth: .infinity, minHeight: 40)
                        .foregroundStyle(isOn ? Color.ink : .bone)
                        .background(isOn ? Color.signal : .clear, in: shape)
                        .overlay { shape.strokeBorder(isOn ? Color.signal : .graphite, lineWidth: Stroke.hairline) }
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(AppCalendar.calendar.weekdaySymbols[weekday - 1])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, Space.xxs)
    }
}

/// Cuadrícula de SF Symbols para elegir el ícono.
struct SymbolPickerView: View {
    @Binding var selection: String
    let colorHex: String
    @Environment(\.dismiss) private var dismiss

    static let symbols: [String] = [
        "checkmark.circle.fill", "star.fill", "heart.fill", "flame.fill", "bolt.fill", "sparkles",
        "drop.fill", "cup.and.saucer.fill", "fork.knife", "carrot.fill", "pills.fill", "cross.case.fill",
        "bed.double.fill", "moon.fill", "sun.max.fill", "leaf.fill", "tree.fill", "mountain.2.fill",
        "figure.walk", "figure.run", "figure.strengthtraining.traditional", "figure.yoga",
        "figure.mind.and.body", "bicycle", "dumbbell.fill", "sportscourt.fill", "lungs.fill", "scalemass.fill",
        "book.fill", "books.vertical.fill", "graduationcap.fill", "pencil", "lightbulb.fill", "brain.head.profile",
        "laptopcomputer", "music.note", "guitars.fill", "paintbrush.fill", "camera.fill", "globe",
        "person.2.fill", "phone.fill", "message.fill", "house.fill", "cart.fill", "banknote.fill",
        "clock.fill", "alarm.fill", "timer", "hourglass", "calendar", "checklist",
        "shower.fill", "tshirt.fill", "pawprint.fill", "water.waves", "figure.boxing", "figure.pool.swim",
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52), spacing: Space.s)], spacing: Space.s) {
                ForEach(Self.symbols, id: \.self) { symbol in
                    let isSelected = selection == symbol
                    Button {
                        selection = symbol
                        dismiss()
                    } label: {
                        SymbolBadge(symbol: symbol, colorHex: isSelected ? colorHex : "8C8C8C", size: 48)
                            .overlay {
                                if isSelected {
                                    RoundedRectangle(cornerRadius: Radius.sharp, style: .continuous)
                                        .strokeBorder(.bone, lineWidth: 2)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(symbol)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            .padding(Space.m)
        }
        .background(Color.ink.ignoresSafeArea())
        .navigationTitle("Ícono")
        .navigationBarTitleDisplayMode(.inline)
    }
}
