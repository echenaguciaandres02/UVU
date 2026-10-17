import XCTest

/// Video de presentación: aparece al abrir la app y se salta con un toque.
final class SplashUITests: XCTestCase {
    func testSplashShowsAndCanBeSkipped() {
        let app = XCUIApplication()
        app.launchArguments = ["-uvu-splash", "-uvu-no-notifications"]
        app.launch()

        let splash = app.buttons["Presentación de UVU"]
        XCTAssertTrue(splash.waitForExistence(timeout: 5), "La presentación no apareció")
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = "00-presentacion"
        attachment.lifetime = .keepAlways
        add(attachment)

        splash.tap()
        XCTAssertTrue(app.tabBars.buttons["Hoy"].waitForExistence(timeout: 5))
        let gone = NSPredicate(format: "exists == false")
        expectation(for: gone, evaluatedWith: splash)
        waitForExpectations(timeout: 5)
    }
}
