import SwiftUI
import WidgetKit

/// Extensión de widgets de UVU. Por ahora solo la Live Activity del descanso;
/// los widgets de pantalla de inicio llegan en la fase 7.
@main
struct UVUWidgetsBundle: WidgetBundle {
    var body: some Widget {
        RestTimerLiveActivity()
    }
}
