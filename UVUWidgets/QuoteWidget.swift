import SwiftUI
import WidgetKit

/// Widget "Frase del día" para la pantalla de inicio: póster rojo con la frase de hoy.
/// También sirve para comprobar que la extensión UVUWidgets está instalada en el iPhone.
struct QuoteWidget: Widget {
    var body: some WidgetConfiguration {
        StaticConfiguration(kind: "QuoteWidget", provider: QuoteProvider()) { entry in
            QuoteWidgetView(entry: entry)
                .containerBackground(QuotePalette.signal, for: .widget)
        }
        .configurationDisplayName("Frase del día")
        .description("La frase de UVU de hoy.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

private enum QuotePalette {
    static let ink = Color(red: 10 / 255, green: 10 / 255, blue: 10 / 255)
    static let signal = Color(red: 212 / 255, green: 42 / 255, blue: 32 / 255)
}

struct QuoteEntry: TimelineEntry {
    let date: Date
    let quote: String
}

struct QuoteProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuoteEntry {
        QuoteEntry(date: .now, quote: Quotes.quotedOfTheDay())
    }

    func getSnapshot(in context: Context, completion: @escaping (QuoteEntry) -> Void) {
        completion(placeholder(in: context))
    }

    /// Una entrada hoy y otra a medianoche, cuando cambia la frase.
    func getTimeline(in context: Context, completion: @escaping (Timeline<QuoteEntry>) -> Void) {
        let now = Date.now
        let midnight = AppCalendar.calendar.date(byAdding: .day, value: 1, to: AppCalendar.startOfDay(now)) ?? now
        let entries = [QuoteEntry(date: now, quote: Quotes.quotedOfTheDay(now)),
                       QuoteEntry(date: midnight, quote: Quotes.quotedOfTheDay(midnight))]
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}

private struct QuoteWidgetView: View {
    let entry: QuoteEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Spacer(minLength: 0)
            Text(entry.quote)
                .font(.system(size: 22, weight: .black, design: .default).width(.condensed))
                .foregroundStyle(QuotePalette.ink)
                .minimumScaleFactor(0.5)
                .lineLimit(5)
            Text("FRASE DEL DÍA")
                .font(.system(size: 9, weight: .black))
                .tracking(1.4)
                .foregroundStyle(QuotePalette.ink.opacity(0.8))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }
}
