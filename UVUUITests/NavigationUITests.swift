import XCTest

/// Recorre las pantallas de Hábitos tocando los botones, y comprueba que la app
/// sigue respondiendo después de cada navegación (que no se cuelga).
final class NavigationUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
        app.tabBars.buttons["Hábitos"].tap()
        XCTAssertTrue(app.navigationBars["Hábitos"].waitForExistence(timeout: 10))
    }

    func testGeneralCalendarOpensAndGoesBack() {
        app.buttons["Calendario general"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Calendario general"].waitForExistence(timeout: 10),
                      "El calendario general no se abrió")

        app.navigationBars["Calendario general"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Hábitos"].waitForExistence(timeout: 10),
                      "No se pudo volver a Hábitos")
    }

    func testHabitDetailOpensAndGoesBack() {
        app.staticTexts["Lectura"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Lectura"].waitForExistence(timeout: 10),
                      "El detalle del hábito no se abrió")

        app.navigationBars["Lectura"].buttons.firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Hábitos"].waitForExistence(timeout: 10))
    }

    func testArchivedOpensFromMenu() {
        app.buttons["Más opciones"].firstMatch.tap()
        app.buttons["Archivados"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Archivados"].waitForExistence(timeout: 10),
                      "Archivados no se abrió")
    }
}
