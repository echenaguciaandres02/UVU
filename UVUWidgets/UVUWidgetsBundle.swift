import SwiftUI
import WidgetKit

/// Extensión de widgets de UVU: la Live Activity del descanso y el widget "Frase del día";
/// el resto de widgets de pantalla de inicio llegan en la fase 7.
@main
struct UVUWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RestTimerLiveActivity()
        QuoteWidget()
    }
}
