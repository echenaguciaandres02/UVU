import XCTest

/// Entreno completo: empezar la rutina de hoy, marcar una serie (arranca el descanso),
/// terminar y verlo en el historial.
final class GymUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uvu-demo-data", "-uvu-no-notifications"]
        app.launch()
        app.tabBars.buttons["Gym"].tap()
        XCTAssertTrue(app.navigationBars["GYM"].waitForExistence(timeout: 10))
    }

    func testWorkoutFromStartToHistory() {
        // Los datos de ejemplo asignan Push al día de hoy.
        app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Empezar")).firstMatch.tap()

        let firstSet = app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Marcar serie 1")).firstMatch
        XCTAssertTrue(firstSet.waitForExistence(timeout: 10), "La sesión en vivo no se abrió")
        firstSet.tap()

        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Saltar")).firstMatch
            .waitForExistence(timeout: 5), "El temporizador de descanso no arrancó")

        app.buttons["Terminar"].firstMatch.tap()
        app.buttons["Terminar entreno"].firstMatch.tap()

        let done = app.buttons.matching(NSPredicate(format: "label ==[c] %@", "Listo")).firstMatch
        XCTAssertTrue(done.waitForExistence(timeout: 10), "No apareció el resumen del entreno")
        done.tap()

        app.collectionViews.buttons.matching(NSPredicate(format: "label == %@", "Historial")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Push")).firstMatch
            .waitForExistence(timeout: 10) ||
            app.buttons.matching(NSPredicate(format: "label CONTAINS[c] %@", "Push")).firstMatch.exists,
            "El entreno no aparece en el historial")
    }
}
