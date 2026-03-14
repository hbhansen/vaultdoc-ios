import Foundation

enum YearFormatter {
    static func display(_ year: Int) -> String {
        let formatter = NumberFormatter()
        formatter.locale = LanguageSettings.shared.locale
        formatter.numberStyle = .none
        formatter.usesGroupingSeparator = false
        return formatter.string(from: NSNumber(value: year)) ?? String(year)
    }

    static func display(date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = LanguageSettings.shared.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func date(fromYear year: Int) -> Date {
        let components = DateComponents(year: year, month: 1, day: 1)
        return Calendar.autoupdatingCurrent.date(from: components) ?? Date()
    }

    static func year(from date: Date) -> Int {
        Calendar.autoupdatingCurrent.component(.year, from: date)
    }

    static var currentYear: Int {
        Calendar.autoupdatingCurrent.component(.year, from: Date())
    }

    static var currentDate: Date {
        Date()
    }
}
