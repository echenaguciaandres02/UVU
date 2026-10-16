import XCTest
import SwiftUI
import UIKit
@testable import UVU

final class DesignSystemTests: XCTestCase {

    func testAllBundledFontsAreRegistered() {
        for name in FontName.all {
            XCTAssertNotNil(UIFont(name: name, size: 17), "Falta registrar la fuente \(name)")
        }
    }

    func testPaletteColorsExistInAssetCatalog() {
        for name in ["ink", "carbon", "graphite", "ash", "bone", "signal", "signalDeep", "brass"] {
            XCTAssertNotNil(UIColor(named: name), "Falta el color \(name) en el Asset Catalog")
        }
    }

    func testQuoteOfTheDayIsStableWithinADayAndRotates() {
        let calendar = AppCalendar.calendar
        let morning = calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 4))!
        let night = calendar.date(from: DateComponents(year: 2026, month: 10, day: 16, hour: 23))!
        let tomorrow = calendar.date(byAdding: .day, value: 1, to: morning)!

        XCTAssertEqual(Quotes.ofTheDay(morning), Quotes.ofTheDay(night))
        XCTAssertNotEqual(Quotes.ofTheDay(morning), Quotes.ofTheDay(tomorrow))
        XCTAssertTrue(Quotes.all.contains(Quotes.ofTheDay(morning)))
    }

    func testDateLineFormat() {
        let date = AppCalendar.calendar.date(from: DateComponents(year: 2026, month: 10, day: 16))!
        XCTAssertEqual(PosterHeader.dateLine(date), "VIERNES · 16 OCT")
    }

    func testMutedHabitColorKeepsHueButLosesSaturation() {
        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0, alpha: CGFloat = 0
        UIColor(Color.muted(hex: "007AFF")).getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha)
        XCTAssertLessThan(saturation, 0.45)
        XCTAssertEqual(brightness, 0.74, accuracy: 0.02)
        XCTAssertEqual(hue, 0.58, accuracy: 0.03, "Debe seguir siendo azul")
    }
}
