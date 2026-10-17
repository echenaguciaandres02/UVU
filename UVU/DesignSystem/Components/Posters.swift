import SwiftUI

/// Titular gigante en Anton sobre `ink`, con la fecha en mayúsculas debajo.
struct PosterHeader: View {
    let title: String
    var subtitle: String?
    var size: CGFloat = 72

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xxs) {
            Text(title)
                .posterTitle(size)
            if let subtitle {
                Text(subtitle)
                    .labelCaps(13)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }

    /// "VIERNES · 16 OCT"
    static func dateLine(_ date: Date = .now) -> String {
        let weekday = date.formatted(.dateTime.weekday(.wide).locale(AppLocale.spanish))
        let day = date.formatted(.dateTime.day().locale(AppLocale.spanish))
        let month = date.formatted(.dateTime.month(.abbreviated).locale(AppLocale.spanish))
            .replacingOccurrences(of: ".", with: "")
        return "\(weekday) · \(day) \(month)".uppercased()
    }
}

/// Bloque rojo con grano y texto negro en Anton: frase del día, estados vacíos, "día completo".
struct RedPoster: View {
    let text: String
    var caption: String?
    var minHeight: CGFloat = 220
    var textSize: CGFloat = 52
    /// Espacio libre arriba (por ejemplo, para la cinta "DO." encima del póster).
    var topInset: CGFloat = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            Spacer(minLength: topInset)
            Text(text)
                .font(.display(textSize, relativeTo: .largeTitle))
                .textCase(.uppercase)
                .tracking(-0.5)
                .foregroundStyle(.ink)
                .minimumScaleFactor(0.5)
                .fixedSize(horizontal: false, vertical: true)
            if let caption {
                // Inter Black ≥ 15 pt: texto "grande" para el contraste negro sobre rojo.
                Text(caption)
                    .font(.ui(15, .black, relativeTo: .subheadline))
                    .textCase(.uppercase)
                    .tracking(1.5)
                    .foregroundStyle(.ink)
            }
        }
        .padding(Space.l)
        .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .bottomLeading)
        .background(.signal)
        .grain(.poster)
        .clipShape(RoundedRectangle(cornerRadius: Radius.sharp, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

/// Cinta adhesiva translúcida con una palabra en Inter Black (ej. "DO."), ligeramente torcida.
struct TapeLabel: View {
    let text: String
    var rotation: Double = -3

    var body: some View {
        Text(text)
            .font(.ui(30, .black, relativeTo: .title))
            .foregroundStyle(.ink)
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.s)
            .background {
                TapeShape()
                    .fill(Color.bone.opacity(0.32))
                    .overlay {
                        TapeShape().fill(
                            LinearGradient(colors: [Color.white.opacity(0.22), .clear, Color.white.opacity(0.1)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                    }
            }
            .rotationEffect(.degrees(rotation))
            .accessibilityLabel(text)
    }
}

/// Rectángulo con los extremos cortados en zigzag, como cinta rasgada a mano.
struct TapeShape: Shape {
    func path(in rect: CGRect) -> Path {
        let teeth = 7
        let depth: CGFloat = 4
        let step = rect.height / CGFloat(teeth)
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        for index in 0..<teeth {
            let y = rect.minY + step * CGFloat(index)
            path.addLine(to: CGPoint(x: rect.maxX - depth, y: y + step / 2))
            path.addLine(to: CGPoint(x: rect.maxX, y: y + step))
        }
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        for index in 0..<teeth {
            let y = rect.maxY - step * CGFloat(index)
            path.addLine(to: CGPoint(x: rect.minX + depth, y: y - step / 2))
            path.addLine(to: CGPoint(x: rect.minX, y: y - step))
        }
        path.closeSubpath()
        return path
    }
}

/// Frase editorial en Cormorant, centrada entre dos líneas finas.
struct QuoteCard: View {
    let text: String

    var body: some View {
        VStack(spacing: Space.l) {
            Rectangle().fill(.graphite).frame(height: Stroke.hairline)
            Text(text)
                .editorialQuote(26)
                .padding(.horizontal, Space.l)
            Rectangle().fill(.graphite).frame(height: Stroke.hairline)
        }
        .padding(.vertical, Space.s)
    }
}

/// Pantalla roja breve al completar todos los hábitos del día.
struct DayCompleteOverlay: View {
    var body: some View {
        ZStack {
            Color.signal.ignoresSafeArea()
                .grain(.poster)
            VStack(alignment: .leading, spacing: Space.m) {
                Spacer()
                Text(Quotes.dayComplete)
                    .font(.display(84, relativeTo: .largeTitle))
                    .textCase(.uppercase)
                    .tracking(-1)
                    .foregroundStyle(.ink)
                    .minimumScaleFactor(0.5)
                TapeLabel(text: "DO.")
                Spacer().frame(height: Space.xxl)
            }
            .padding(Space.l)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isModal)
    }
}

#Preview {
    ScrollView {
        VStack(spacing: Space.l) {
            PosterHeader(title: "Hoy.", subtitle: PosterHeader.dateLine())
            RedPoster(text: Quotes.quotedOfTheDay(), caption: "Frase del día")
                .overlay(alignment: .topTrailing) { TapeLabel(text: "DO.").padding(Space.m) }
            QuoteCard(text: "Empieza donde estás.")
        }
        .padding()
    }
    .background(Color.ink)
}
