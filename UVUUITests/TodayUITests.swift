import XCTest

/// Pantalla Hoy: marcar un hábito con un toque y abrir el calendario unificado.
final class TodayUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launch()
    }

    func testMarkHabitFromToday() {
        let mark = app.buttons["Marcar Tomar creatina"].firstMatch
        if !mark.waitForExistence(timeout: 5) {
            app.swipeUp(velocity: .slow)
        }
        XCTAssertTrue(mark.waitForExistence(timeout: 10), "El hábito no aparece en Hoy")
        mark.tap()
        XCTAssertTrue(app.buttons["Desmarcar Tomar creatina"].firstMatch.waitForExistence(timeout: 10),
                      "El hábito no quedó marcado")
        // Se desmarca para no dejar el día cambiado.
        app.buttons["Desmarcar Tomar creatina"].firstMatch.tap()
    }

    func testUnifiedCalendarOpensAndCloses() {
        app.buttons["Calendario"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["CALENDARIO"].waitForExistence(timeout: 10),
                      "El calendario unificado no se abrió")
        app.buttons["Listo"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Calendario"].firstMatch.waitForExistence(timeout: 10))
    }
}
