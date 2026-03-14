import Foundation

struct CurrencyFormatter {
    static let euro: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = "EUR"
        f.currencySymbol = "€"
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f
    }()

    static func format(_ value: Double) -> String {
        euro.string(from: NSNumber(value: value)) ?? "€\(value)"
    }
}
