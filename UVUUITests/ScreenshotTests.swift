import XCTest

/// Toma capturas de la galería del sistema visual y de cada pantalla, con datos de ejemplo
/// en memoria. La compilación en la nube las exporta como el artefacto "Capturas".
/// Una prueba por sección: cada prueba tiene un límite de 2 minutos.
final class ScreenshotTests: XCTestCase {
    private let demo = ["-uvu-demo-data"]
    private let largeText = ["-uvu-demo-data",
                             "-UIPreferredContentSizeCategoryName", "UICTContentSizeCategoryAccessibilityL"]

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

    func testTodayScreens() {
        let app = launch(demo)
        snap(app, "01-hoy")
        for page in 2...4 {
            app.swipeUp(velocity: .slow)
            snap(app, "01-hoy-\(page)")
        }
        app.swipeDown(velocity: .fast)
        app.swipeDown(velocity: .fast)
        app.buttons["Calendario"].firstMatch.tap()
        _ = app.navigationBars["CALENDARIO"].waitForExistence(timeout: 10)
        snap(app, "30-calendario")
        app.swipeUp(velocity: .slow)
        snap(app, "31-calendario-dia")
        app.swipeUp(velocity: .slow)
        snap(app, "32-calendario-dia-2")
    }

    func testHabitsScreens() {
        let app = launch(demo)
        habits(app, prefix: "")
        app.buttons["Nuevo hábito"].firstMatch.tap()
        sleep(1)
        snap(app, "07-nuevo-habito")
        app.buttons["Cancelar"].firstMatch.tap()
    }

    func testTasksScreens() {
        let app = launch(demo)
        tasks(app, prefix: "")
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
    }

    func testJournalScreens() {
        let app = launch(demo)
        app.tabBars.buttons["Journal"].tap()
        _ = app.navigationBars["JOURNAL"].waitForExistence(timeout: 10)
        snap(app, "19-journal")
        app.swipeUp(velocity: .slow)
        snap(app, "20-journal-entradas")
        app.swipeDown(velocity: .fast)
        tapLabel(app, "Calendario")
        snap(app, "21-journal-calendario")
        tapLabel(app, "Entradas")
        app.buttons.matching(NSPredicate(format: "label == %@", "Escribir hoy")).firstMatch.tap()
        sleep(1)
        snap(app, "22-journal-editor")
        app.swipeUp(velocity: .slow)
        snap(app, "23-journal-editor-2")
    }

    func testGymScreens() {
        let app = launch(demo)
        app.tabBars.buttons["Gym"].tap()
        _ = app.navigationBars["GYM"].waitForExistence(timeout: 10)
        snap(app, "24-gym")
        tapLabel(app, "Historial")
        snap(app, "25-gym-historial")
        tapLabel(app, "Ejercicios")
        app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "Press de banca")).firstMatch.tap()
        sleep(1)
        snap(app, "26-gym-progreso")
        app.navigationBars.buttons.firstMatch.tap()
        tapLabel(app, "Rutinas")
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH[c] %@", "Push,")).firstMatch.tap()
        sleep(1)
        app.swipeUp(velocity: .slow)
        snap(app, "29-gym-rutina")
    }

    /// Separada de `testGymScreens` para no pasar el límite de 2 minutos por prueba.
    func testGymSessionScreens() {
        let app = launch(demo)
        app.tabBars.buttons["Gym"].tap()
        _ = app.navigationBars["GYM"].waitForExistence(timeout: 10)
        app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Empezar")).firstMatch.tap()
        sleep(2)
        snap(app, "27-gym-sesion")
        // Marcar la primera serie arranca el descanso.
        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Marcar serie 1")).firstMatch.tap()
        sleep(1)
        snap(app, "28-gym-descanso")
    }

    func testSettingsScreen() {
        let app = launch(demo)
        app.buttons["Ajustes"].firstMatch.tap()
        sleep(1)
        snap(app, "11-ajustes")
    }

    func testScreensWithLargeText() {
        let app = launch(largeText)
        snap(app, "texto-grande-01-hoy")
        habits(app, prefix: "texto-grande-")
        tasks(app, prefix: "texto-grande-")
    }

    // MARK: - Recorridos compartidos

    private func habits(_ app: XCUIApplication, prefix: String) {
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
    }

    private func tasks(_ app: XCUIApplication, prefix: String) {
        app.tabBars.buttons["Tareas"].tap()
        _ = app.navigationBars["TAREAS"].waitForExistence(timeout: 10)
        snap(app, "\(prefix)12-tareas-hoy")
        tapLabel(app, "Próximos")
        snap(app, "\(prefix)13-tareas-proximos")
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
