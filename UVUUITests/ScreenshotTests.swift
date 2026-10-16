import XCTest

/// Toma capturas de la galería del sistema visual y de cada pantalla, con datos de ejemplo
/// en memoria. La compilación en la nube las exporta como el artefacto "Capturas".
final class ScreenshotTests: XCTestCase {

    override func setUp() {
        continueAfterFailure = true
    }

    func testGallery() {
        let app = launch(["-uvu-gallery"])
        snap(app, "00-galeria-1")
        for page in 2...5 {
            app.swipeUp(velocity: .slow)
            snap(app, "00-galeria-\(page)")
        }
    }

    func testScreens() {
        let app = launch(["-uvu-demo-data"])
        tour(app, prefix: "")
    }

    func testScreensWithLargeText() {
        let app = launch(["-uvu-demo-data",
                          "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"])
        tour(app, prefix: "texto-grande-")
    }

    // MARK: - Recorrido

    private func tour(_ app: XCUIApplication, prefix: String) {
        snap(app, "\(prefix)01-hoy")

        app.tabBars.buttons["Hábitos"].tap()
        _ = app.navigationBars["HÁBITOS"].waitForExistence(timeout: 10)
        snap(app, "\(prefix)02-habitos")

        app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Tomar agua")).firstMatch.tap()
        _ = app.navigationBars["TOMAR AGUA"].waitForExistence(timeout: 10)
        snap(app, "\(prefix)03-detalle")
        app.swipeUp(velocity: .slow)
        snap(app, "\(prefix)04-detalle-calendario")
        app.navigationBars.buttons.firstMatch.tap()

        app.buttons["Calendario general"].firstMatch.tap()
        _ = app.navigationBars["CALENDARIO"].waitForExistence(timeout: 10)
        snap(app, "\(prefix)05-calendario")
        app.swipeUp(velocity: .slow)
        snap(app, "\(prefix)06-calendario-dia")
        app.navigationBars.buttons.firstMatch.tap()

        // Tareas
        app.tabBars.buttons["Tareas"].tap()
        _ = app.navigationBars["TAREAS"].waitForExistence(timeout: 10)
        snap(app, "\(prefix)12-tareas-hoy")
        tapLabel(app, "Próximos")
        snap(app, "\(prefix)13-tareas-proximos")

        guard prefix.isEmpty else { return }

        tapLabel(app, "Todas")
        snap(app, "14-tareas-todas")
        tapLabel(app, "Hechas")
        snap(app, "15-tareas-hechas")
        tapLabel(app, "Hoy")
        // El checkbox se llama "Completar Entregar capítulo…": se excluye para abrir la tarea, no completarla.
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@ AND NOT (label BEGINSWITH %@)",
                                         "Entregar capítulo", "Completar")).firstMatch.tap()
        sleep(1)
        snap(app, "16-tarea-detalle")
        app.swipeUp(velocity: .slow)
        snap(app, "17-tarea-detalle-2")
        app.buttons["Cancelar"].firstMatch.tap()
        app.buttons["Mis listas"].firstMatch.tap()
        _ = app.navigationBars["LISTAS"].waitForExistence(timeout: 10)
        snap(app, "18-listas")
        app.navigationBars.buttons.firstMatch.tap()

        app.tabBars.buttons["Hábitos"].tap()
        app.buttons["Nuevo hábito"].firstMatch.tap()
        sleep(1)
        snap(app, "07-nuevo-habito")
        app.buttons["Cancelar"].firstMatch.tap()

        app.tabBars.buttons["Journal"].tap()
        snap(app, "09-journal")
        app.tabBars.buttons["Gym"].tap()
        snap(app, "10-gym")

        app.tabBars.buttons["Hoy"].tap()
        app.buttons["Ajustes"].firstMatch.tap()
        sleep(1)
        snap(app, "11-ajustes")
    }

    // MARK: - Utilidades

    /// Toca un botón del contenido (no de la barra de pestañas, que también tiene "Hoy").
    private func tapLabel(_ app: XCUIApplication, _ label: String) {
        app.collectionViews.buttons.matching(NSPredicate(format: "label == %@", label)).firstMatch.tap()
        sleep(1)
    }

    private func launch(_ arguments: [String]) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = arguments
        app.launch()
        sleep(2)
        return app
    }

    private func snap(_ app: XCUIApplication, _ name: String) {
        sleep(1)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
