import Foundation

enum YearFormatter {
    static func display(_ year: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = LanguageSettings.shared.locale
        formatter.numberStyle = .none
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: year)) ?? String(year)
    }

    static var currentYear: Int {
        Calendar.autoupdatingCurrent.component(.year, from: Date())
    }
}
