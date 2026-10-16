import SwiftUI

/// Paleta de colores para elegir el color de un hábito, lista o rutina.
struct ColorPaletteView: View {
    @Binding var selection: String

    private let columns = Array(repeating: GridItem(.flexible()), count: 6)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(AppPalette.colors, id: \.self) { hex in
                Button {
                    selection = hex
                } label: {
                    Circle()
                        .fill(Color(hex: hex))
                        .frame(width: 32, height: 32)
                        .overlay {
                            if selection == hex {
                                Image(systemName: "checkmark")
                                    .font(.caption.bold())
                                    .foregroundStyle(.white)
                            }
                        }
                }
                .buttonStyle(.borderless)
                .accessibilityLabel("Color")
                .accessibilityAddTraits(selection == hex ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }
}

/// Selector de días de la semana (L M X J V S D).
struct WeekdayPicker: View {
    @Binding var selection: Set<Int>

    var body: some View {
        HStack(spacing: 6) {
            ForEach(AppCalendar.orderedWeekdays, id: \.self) { weekday in
                let isOn = selection.contains(weekday)
                Button {
                    if isOn {
                        selection.remove(weekday)
                    } else {
                        selection.insert(weekday)
                    }
                } label: {
                    Text(AppCalendar.veryShortWeekdayName(weekday))
                        .font(.subheadline.weight(.semibold))
                        .frame(width: 38, height: 38)
                        .background(isOn ? Color.accentColor : Color(.tertiarySystemFill), in: Circle())
                        .foregroundStyle(isOn ? Color.white : Color.primary)
                }
                .buttonStyle(.borderless)
                .frame(maxWidth: .infinity)
                .accessibilityLabel(AppCalendar.calendar.weekdaySymbols[weekday - 1])
                .accessibilityAddTraits(isOn ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
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
        "shower.fill", "tshirt.fill", "pawprint.fill", "water.waves", "face.smiling", "hand.thumbsup.fill",
    ]

    var body: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 52))], spacing: 14) {
                ForEach(Self.symbols, id: \.self) { symbol in
                    Button {
                        selection = symbol
                        dismiss()
                    } label: {
                        SymbolBadge(symbol: symbol, colorHex: selection == symbol ? colorHex : "8E8E93", size: 46)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(symbol)
                    .accessibilityAddTraits(selection == symbol ? .isSelected : [])
                }
            }
            .padding()
        }
        .navigationTitle("Ícono")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Anillo de progreso (para hábitos cuantitativos).
struct ProgressRing: View {
    let progress: Double
    let color: Color
    var lineWidth: CGFloat = 4

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(max(progress, 0), 1))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            if progress >= 1 {
                Image(systemName: "checkmark")
                    .font(.caption.bold())
                    .foregroundStyle(color)
            }
        }
    }
}
