import XCTest

/// Flujo completo de una tarea: crearla, verla en Hoy, completarla deslizando y encontrarla en Hechas.
final class TasksUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        app = XCUIApplication()
        // Base en memoria y sin pedir permisos de notificaciones.
        app.launchArguments = ["-uvu-demo-data", "-uvu-no-notifications"]
        app.launch()
        app.tabBars.buttons["Tareas"].tap()
        XCTAssertTrue(app.navigationBars["TAREAS"].waitForExistence(timeout: 10))
    }

    func testCreateCompleteAndFindInDone() {
        let title = "Comprar café \(Int.random(in: 100...999))"

        app.buttons["Nueva tarea"].firstMatch.tap()
        let field = app.descendants(matching: .any)["task-title"].firstMatch
        XCTAssertTrue(field.waitForExistence(timeout: 10), "El formulario no se abrió")
        field.tap()
        field.typeText(title)
        app.buttons["Guardar"].firstMatch.tap()

        // Creada desde "Hoy", vence hoy: aparece en la vista Hoy.
        let row = app.staticTexts[title].firstMatch
        XCTAssertTrue(row.waitForExistence(timeout: 10), "La tarea nueva no aparece en Hoy")

        // Deslizar a la derecha muestra "Completar" (o la completa si el deslizamiento es largo).
        row.swipeRight()
        let completeButton = app.buttons.matching(NSPredicate(format: "label == %@", "Completar")).firstMatch
        if completeButton.waitForExistence(timeout: 3) {
            completeButton.tap()
        }
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: row)
        waitForExpectations(timeout: 10)

        app.buttons.matching(NSPredicate(format: "label == %@", "Hechas")).firstMatch.tap()
        XCTAssertTrue(app.staticTexts[title].firstMatch.waitForExistence(timeout: 10),
                      "La tarea completada no aparece en Hechas")
    }

    func testListsScreenOpens() {
        app.buttons["Mis listas"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["LISTAS"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.staticTexts.matching(NSPredicate(format: "label ==[c] %@", "Universidad")).firstMatch.exists)
    }
}
