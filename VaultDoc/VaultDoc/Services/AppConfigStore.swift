import Foundation

@Observable
class AppConfigStore {
    static let shared = AppConfigStore()

    var categories: [RemoteCategory] = AppConfigStore.defaultCategories
    var currencies: [RemoteCurrency] = AppConfigStore.defaultCurrencies
    var defaultCurrencyCode: String = "EUR"
    var isLoading = false
    var lastError: String?

    private let categoriesCacheKey = "cached_categories"
    private let currenciesCacheKey = "cached_currencies"
    private let defaultCurrencyKeyPrefix = "default_currency_code"

    private init() {
        loadFromCache()
    }

    // MARK: - Refresh from Supabase

    func refresh(supabaseURL: String, supabaseKey: String) async {
        guard !supabaseURL.isEmpty, !supabaseKey.isEmpty else { return }
        isLoading = true
        lastError = nil

        async let cats = try? RemoteConfigService.fetchCategories(supabaseURL: supabaseURL, supabaseKey: supabaseKey)
        async let currs = try? RemoteConfigService.fetchCurrencies(supabaseURL: supabaseURL, supabaseKey: supabaseKey)

        if let fetched = await cats, !fetched.isEmpty {
            categories = fetched
            persist(fetched, forKey: categoriesCacheKey)
        }
        if let fetched = await currs, !fetched.isEmpty {
            currencies = fetched
            persist(fetched, forKey: currenciesCacheKey)
        }
        normalizeDefaultCurrency()
        isLoading = false
    }

    // MARK: - Helpers

    func category(named name: String) -> RemoteCategory? {
        categories.first { $0.name == name }
    }

    func currency(code: String) -> RemoteCurrency? {
        currencies.first { $0.code == code }
    }

    func setDefaultCurrency(code: String) {
        guard currency(code: code) != nil else { return }
        defaultCurrencyCode = code
    }

    func loadDefaultCurrency(userId: String) {
        if let cached = UserDefaults.standard.string(forKey: defaultCurrencyKey(for: userId)) {
            defaultCurrencyCode = cached
        }
        normalizeDefaultCurrency(userId: userId)
    }

    func syncDefaultCurrency(userId: String) async {
        loadDefaultCurrency(userId: userId)

        do {
            if let profile = try await SupabaseDataService.fetchUserProfile(userId: userId),
               let remoteCurrency = profile.defaultCurrency,
               currency(code: remoteCurrency) != nil {
                defaultCurrencyCode = remoteCurrency
                persistDefaultCurrency(for: userId)
            }
        } catch {
            lastError = error.localizedDescription
        }
    }

    func saveDefaultCurrency(userId: String) async throws {
        normalizeDefaultCurrency(userId: userId)
        persistDefaultCurrency(for: userId)
        let payload = UserProfilePayload(id: userId, defaultCurrency: defaultCurrencyCode)
        _ = try await SupabaseDataService.upsertUserProfile(payload)
    }

    // MARK: - Persistence (UserDefaults cache)

    private func persist<T: Encodable>(_ value: T, forKey key: String) {
        if let data = try? JSONEncoder().encode(value) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    private func loadFromCache() {
        let decoder = JSONDecoder()
        if let data = UserDefaults.standard.data(forKey: categoriesCacheKey),
           let cached = try? decoder.decode([RemoteCategory].self, from: data), !cached.isEmpty {
            categories = cached
        }
        if let data = UserDefaults.standard.data(forKey: currenciesCacheKey),
           let cached = try? decoder.decode([RemoteCurrency].self, from: data), !cached.isEmpty {
            currencies = cached
        }
        normalizeDefaultCurrency()
    }

    private func normalizeDefaultCurrency(userId: String? = nil) {
        if currency(code: defaultCurrencyCode) == nil {
            defaultCurrencyCode = currencies.first?.code ?? "EUR"
            if let userId {
                persistDefaultCurrency(for: userId)
            }
        }
    }

    private func persistDefaultCurrency(for userId: String) {
        UserDefaults.standard.set(defaultCurrencyCode, forKey: defaultCurrencyKey(for: userId))
    }

    private func defaultCurrencyKey(for userId: String) -> String {
        "\(defaultCurrencyKeyPrefix)_\(userId)"
    }

    // MARK: - Hardcoded fallbacks (app works offline / before first sync)

    static let defaultCategories: [RemoteCategory] = [
        RemoteCategory(id: 1, name: "jewellery",    displayName: "Jewellery",    icon: "sparkles",        sortOrder: 1),
        RemoteCategory(id: 2, name: "art",          displayName: "Art",          icon: "paintpalette",    sortOrder: 2),
        RemoteCategory(id: 3, name: "electronics",  displayName: "Electronics",  icon: "desktopcomputer", sortOrder: 3),
        RemoteCategory(id: 4, name: "furniture",    displayName: "Furniture",    icon: "sofa",            sortOrder: 4),
        RemoteCategory(id: 5, name: "collectibles", displayName: "Collectibles", icon: "star",            sortOrder: 5),
        RemoteCategory(id: 6, name: "other",        displayName: "Other",        icon: "archivebox",      sortOrder: 6),
    ]

    static let defaultCurrencies: [RemoteCurrency] = [
        RemoteCurrency(id: 1, code: "EUR", symbol: "€",  name: "Euro"),
        RemoteCurrency(id: 2, code: "USD", symbol: "$",  name: "US Dollar"),
        RemoteCurrency(id: 3, code: "GBP", symbol: "£",  name: "British Pound"),
        RemoteCurrency(id: 4, code: "DKK", symbol: "kr", name: "Danish Krone"),
        RemoteCurrency(id: 5, code: "SEK", symbol: "kr", name: "Swedish Krona"),
    ]
}
