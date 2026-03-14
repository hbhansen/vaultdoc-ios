import Foundation

struct CurrencyFormatter {

    static func format(_ value: Double, code: String = "EUR", symbol: String? = nil) -> String {
        let f = NumberFormatter()
        f.numberStyle = .currency
        f.currencyCode = code
        if let symbol { f.currencySymbol = symbol }
        f.maximumFractionDigits = 2
        f.minimumFractionDigits = 0
        return f.string(from: NSNumber(value: value)) ?? "\(symbol ?? code) \(value)"
    }

    static func format(_ value: Double, for item: Item, config: AppConfigStore) -> String {
        let currency = config.currency(code: item.currency)
        return format(value, code: item.currency, symbol: currency?.symbol)
    }
}
