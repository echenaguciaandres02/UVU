import Foundation

/// Convierte números a texto y de vuelta, aceptando coma o punto decimal.
enum NumberText {
    static func parse(_ text: String) -> Double? {
        let cleaned = text
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: ",", with: ".")
        return Double(cleaned)
    }

    static func format(_ value: Double) -> String {
        value.formatted(.number.locale(AppLocale.spanish).grouping(.never).precision(.fractionLength(0...2)))
    }
}
