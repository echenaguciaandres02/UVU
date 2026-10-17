import XCTest

/// Escribir la entrada de hoy, elegir ánimo y una etiqueta, y encontrarla con la búsqueda.
final class JournalUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        app.launchArguments = ["-uvu-demo-data", "-uvu-no-notifications"]
        app.launch()
        app.tabBars.buttons["Journal"].tap()
        XCTAssertTrue(app.navigationBars["JOURNAL"].waitForExistence(timeout: 10))
    }

    func testWriteTodayAndFindItWithSearch() {
        let word = "Zanahoria\(Int.random(in: 100...999))"

        app.buttons.matching(NSPredicate(format: "label == %@", "Escribir hoy")).firstMatch.tap()
        let text = app.descendants(matching: .any)["journal-text"].firstMatch
        XCTAssertTrue(text.waitForExistence(timeout: 10), "El editor no se abrió")
        text.tap()
        text.typeText("Hoy probé el journal. \(word)")

        app.buttons.matching(NSPredicate(format: "label BEGINSWITH %@", "Bien, 4 de 5")).firstMatch.tap()
        app.buttons["Guardar"].firstMatch.tap()

        // La tarjeta de hoy ahora muestra la entrada.
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label == %@", "Seguir escribiendo")).firstMatch
            .waitForExistence(timeout: 10), "La entrada de hoy no se guardó")

        // Búsqueda: aparece al deslizar hacia abajo.
        app.swipeDown(velocity: .slow)
        let search = app.searchFields.firstMatch
        XCTAssertTrue(search.waitForExistence(timeout: 10))
        search.tap()
        search.typeText(word)
        // Las filas de la lista son botones con todo su contenido en la etiqueta (la tarjeta de hoy no).
        XCTAssertTrue(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", word)).firstMatch
            .waitForExistence(timeout: 10), "La búsqueda no encuentra la entrada")
        XCTAssertFalse(app.buttons.matching(NSPredicate(format: "label CONTAINS %@", "sentadilla")).firstMatch.exists,
                       "La búsqueda debería ocultar las demás entradas")
    }
}
