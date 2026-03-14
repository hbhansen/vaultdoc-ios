import Foundation

enum L10n {
    static func tr(_ key: String) -> String {
        let languageSettings = LanguageSettings.shared
        let localized = NSLocalizedString(key, bundle: languageSettings.bundle, comment: "")
        if localized != key {
            return localized
        }

        return NSLocalizedString(key, bundle: .main, comment: "")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        String(format: tr(key), locale: LanguageSettings.shared.locale, arguments: arguments)
    }

    static func categoryName(_ code: String, fallback: String? = nil) -> String {
        switch code {
        case "jewellery":
            return tr("category.jewellery")
        case "art":
            return tr("category.art")
        case "electronics":
            return tr("category.electronics")
        case "furniture":
            return tr("category.furniture")
        case "collectibles":
            return tr("category.collectibles")
        case "other":
            return tr("category.other")
        default:
            return fallback ?? code.prefix(1).uppercased() + code.dropFirst()
        }
    }

    static func currencyName(code: String, fallback: String) -> String {
        LanguageSettings.shared.locale.localizedString(forCurrencyCode: code) ?? fallback
    }

    static var placeholderDash: String {
        tr("common.placeholder_dash")
    }
}
