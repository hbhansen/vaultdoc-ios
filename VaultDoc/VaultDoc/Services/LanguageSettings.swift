import Foundation

@Observable
final class LanguageSettings {
    static let shared = LanguageSettings()

    enum AppLanguage: String, CaseIterable, Identifiable {
        case english = "en"
        case danish = "da"

        var id: String { rawValue }

        var locale: Locale {
            Locale(identifier: rawValue)
        }

        var bundle: Bundle {
            guard
                let path = Bundle.main.path(forResource: rawValue, ofType: "lproj"),
                let bundle = Bundle(path: path)
            else {
                return .main
            }

            return bundle
        }

        var localizedName: String {
            switch self {
            case .english:
                return L10n.tr("language.english")
            case .danish:
                return L10n.tr("language.danish")
            }
        }
    }

    private let defaultsKey = "selected_app_language"

    var selectedLanguage: AppLanguage {
        didSet {
            UserDefaults.standard.set(selectedLanguage.rawValue, forKey: defaultsKey)
        }
    }

    var locale: Locale {
        selectedLanguage.locale
    }

    var bundle: Bundle {
        selectedLanguage.bundle
    }

    private init() {
        if
            let rawValue = UserDefaults.standard.string(forKey: defaultsKey),
            let language = AppLanguage(rawValue: rawValue)
        {
            selectedLanguage = language
        } else {
            let preferredCode = Locale.preferredLanguages
                .compactMap { Locale(identifier: $0).language.languageCode?.identifier }
                .first(where: { AppLanguage(rawValue: $0) != nil })

            selectedLanguage = AppLanguage(rawValue: preferredCode ?? AppLanguage.english.rawValue) ?? .english
        }
    }
}
