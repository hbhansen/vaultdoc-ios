import Foundation

@MainActor
@Observable
class AppConfigStore {
    static let shared = AppConfigStore()

    struct CategoryGroup: Identifiable, Hashable {
        let parent: RemoteCategory
        let children: [RemoteCategory]

        var id: String { parent.name }
    }

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
            let normalizedCategories = mergedCategories(with: fetched)
            categories = normalizedCategories
            persist(normalizedCategories, forKey: categoriesCacheKey)
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

    var groupedCategories: [CategoryGroup] {
        let categoriesByName = Dictionary(uniqueKeysWithValues: categories.map { ($0.name, $0) })
        var grouped: [CategoryGroup] = []

        for definition in Self.categoryGroupDefinitions {
            guard let parent = categoriesByName[definition.parent] else { continue }
            let children = definition.children.compactMap { categoriesByName[$0] }
            grouped.append(CategoryGroup(parent: parent, children: children))
        }

        let groupedNames = Set(
            Self.categoryGroupDefinitions.flatMap { [$0.parent] + $0.children }
        )
        let ungrouped = categories
            .filter { !groupedNames.contains($0.name) }
            .sorted { $0.sortOrder < $1.sortOrder }

        grouped.append(contentsOf: ungrouped.map { CategoryGroup(parent: $0, children: []) })
        return grouped
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
        let existingProfile = try await SupabaseDataService.fetchUserProfile(userId: userId)
        let payload = UserProfilePayload(
            id: userId,
            email: existingProfile?.email,
            defaultCurrency: defaultCurrencyCode,
            inventoryId: existingProfile?.inventoryId ?? userId
        )
        _ = try await SupabaseDataService.upsertUserProfile(payload)
    }

    func applyProjectCurrency(
        code: String,
        to items: [Item],
        userId: String
    ) async throws {
        guard currency(code: code) != nil else { return }

        setDefaultCurrency(code: code)
        try await saveDefaultCurrency(userId: userId)

        let updates = items
            .filter { $0.currency != code }
            .map { item in
                ItemPayload(
                    id: item.id,
                    userId: item.userId,
                    inventoryId: item.inventoryId,
                    name: item.name,
                    category: item.category,
                    currency: code,
                    purchasePrice: item.purchasePrice,
                    estimatedValue: item.estimatedValue,
                    aiEstimate: item.aiEstimate,
                    yearPurchased: item.yearPurchased,
                    serialNumber: item.serialNumber,
                    notes: item.notes,
                    createdAt: item.createdAt
                )
            }

        try await withThrowingTaskGroup(of: UUID.self) { group in
            for payload in updates {
                group.addTask {
                    _ = try await SupabaseDataService.updateItem(id: payload.id, payload)
                    return payload.id
                }
            }

            var updatedIds = Set<UUID>()
            for try await updatedId in group {
                updatedIds.insert(updatedId)
            }

            for item in items where updatedIds.contains(item.id) {
                item.currency = code
            }
        }
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
            categories = mergedCategories(with: cached)
        }
        if let data = UserDefaults.standard.data(forKey: currenciesCacheKey),
           let cached = try? decoder.decode([RemoteCurrency].self, from: data), !cached.isEmpty {
            currencies = cached
        }
        normalizeDefaultCurrency()
    }

    private func mergedCategories(with remoteCategories: [RemoteCategory]) -> [RemoteCategory] {
        var byName = Dictionary(uniqueKeysWithValues: Self.defaultCategories.map { ($0.name, $0) })

        for category in remoteCategories where !Self.deprecatedCategoryNames.contains(category.name) {
            byName[category.name] = category
        }

        return byName.values.sorted { lhs, rhs in
            if lhs.sortOrder == rhs.sortOrder {
                return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
            }
            return lhs.sortOrder < rhs.sortOrder
        }
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
        RemoteCategory(id: 1,  name: "furniture_household_fixtures", displayName: "Furniture and household fixtures", icon: "sofa", sortOrder: 1),
        RemoteCategory(id: 2,  name: "electronics_appliances", displayName: "Electronics and appliances", icon: "desktopcomputer", sortOrder: 2),
        RemoteCategory(id: 3,  name: "personal_valuables", displayName: "Personal valuables", icon: "sparkles", sortOrder: 3),
        RemoteCategory(id: 4,  name: "clothing_personal_items", displayName: "Clothing and personal items", icon: "hanger", sortOrder: 4),
        RemoteCategory(id: 5,  name: "kitchenware_household_goods", displayName: "Kitchenware and household goods", icon: "fork.knife", sortOrder: 5),
        RemoteCategory(id: 6,  name: "art_decor_documents", displayName: "Art decor and documents", icon: "photo.on.rectangle", sortOrder: 6),
        RemoteCategory(id: 7,  name: "outdoor_items", displayName: "Outdoor items", icon: "bicycle", sortOrder: 7),
        RemoteCategory(id: 8,  name: "miscellaneous", displayName: "Miscellaneous", icon: "archivebox", sortOrder: 8),
        RemoteCategory(id: 9,  name: "sofas_armchairs", displayName: "Sofas armchairs", icon: "sofa", sortOrder: 9),
        RemoteCategory(id: 10, name: "beds_mattresses_wardrobes", displayName: "Beds mattresses wardrobes", icon: "bed.double", sortOrder: 10),
        RemoteCategory(id: 11, name: "dining_tables_chairs", displayName: "Dining tables chairs", icon: "table.furniture", sortOrder: 11),
        RemoteCategory(id: 12, name: "shelving_storage_units", displayName: "Shelving storage units", icon: "books.vertical", sortOrder: 12),
        RemoteCategory(id: 13, name: "desks_office_chairs", displayName: "Desks office chairs", icon: "chair.lounge", sortOrder: 13),
        RemoteCategory(id: 14, name: "lamps_lighting", displayName: "Lamps lighting", icon: "lamp.floor", sortOrder: 14),
        RemoteCategory(id: 15, name: "tvs_media_systems", displayName: "TVs media systems", icon: "tv", sortOrder: 15),
        RemoteCategory(id: 16, name: "laptops_desktops_tablets", displayName: "Laptops desktops tablets", icon: "laptopcomputer", sortOrder: 16),
        RemoteCategory(id: 17, name: "smartphones_smartwatches", displayName: "Smartphones smartwatches", icon: "iphone.gen3", sortOrder: 17),
        RemoteCategory(id: 18, name: "kitchen_appliances", displayName: "Kitchen appliances", icon: "oven", sortOrder: 18),
        RemoteCategory(id: 19, name: "washing_machine_dryer", displayName: "Washing machine dryer", icon: "washer", sortOrder: 19),
        RemoteCategory(id: 20, name: "gaming_consoles", displayName: "Gaming consoles", icon: "gamecontroller", sortOrder: 20),
        RemoteCategory(id: 21, name: "routers_networking_equipment", displayName: "Routers networking equipment", icon: "wifi.router", sortOrder: 21),
        RemoteCategory(id: 22, name: "jewelry", displayName: "Jewelry", icon: "sparkles", sortOrder: 22),
        RemoteCategory(id: 23, name: "watches", displayName: "Watches", icon: "watch.analog", sortOrder: 23),
        RemoteCategory(id: 24, name: "designer_bags", displayName: "Designer bags", icon: "bag", sortOrder: 24),
        RemoteCategory(id: 25, name: "cash", displayName: "Cash", icon: "banknote", sortOrder: 25),
        RemoteCategory(id: 26, name: "collectibles", displayName: "Collectibles", icon: "star", sortOrder: 26),
        RemoteCategory(id: 27, name: "clothing", displayName: "Clothing", icon: "tshirt", sortOrder: 27),
        RemoteCategory(id: 28, name: "shoes_outerwear", displayName: "Shoes outerwear", icon: "shoeprints.fill", sortOrder: 28),
        RemoteCategory(id: 29, name: "sports_equipment", displayName: "Sports equipment", icon: "dumbbell", sortOrder: 29),
        RemoteCategory(id: 30, name: "bags_luggage", displayName: "Bags luggage", icon: "suitcase", sortOrder: 30),
        RemoteCategory(id: 31, name: "pots_pans_utensils", displayName: "Pots pans utensils", icon: "frying.pan", sortOrder: 31),
        RemoteCategory(id: 32, name: "plates_glasses_cutlery", displayName: "Plates glasses cutlery", icon: "wineglass", sortOrder: 32),
        RemoteCategory(id: 33, name: "small_appliances", displayName: "Small appliances", icon: "applescript", sortOrder: 33),
        RemoteCategory(id: 34, name: "food_storage", displayName: "Food storage", icon: "takeoutbag.and.cup.and.straw", sortOrder: 34),
        RemoteCategory(id: 35, name: "cleaning_equipment", displayName: "Cleaning equipment", icon: "spray.bottle", sortOrder: 35),
        RemoteCategory(id: 36, name: "artwork", displayName: "Artwork", icon: "paintpalette", sortOrder: 36),
        RemoteCategory(id: 37, name: "decor_items", displayName: "Decor items", icon: "photo", sortOrder: 37),
        RemoteCategory(id: 38, name: "books", displayName: "Books", icon: "books.vertical", sortOrder: 38),
        RemoteCategory(id: 39, name: "important_documents", displayName: "Important documents", icon: "doc.text", sortOrder: 39),
        RemoteCategory(id: 40, name: "garden_furniture", displayName: "Garden furniture", icon: "tree", sortOrder: 40),
        RemoteCategory(id: 41, name: "tools_equipment", displayName: "Tools equipment", icon: "hammer", sortOrder: 41),
        RemoteCategory(id: 42, name: "bicycles", displayName: "Bicycles", icon: "bicycle", sortOrder: 42),
        RemoteCategory(id: 43, name: "bbq_grill", displayName: "BBQ grill", icon: "flame", sortOrder: 43),
        RemoteCategory(id: 44, name: "toys", displayName: "Toys", icon: "figure.play", sortOrder: 44),
        RemoteCategory(id: 45, name: "hobby_equipment", displayName: "Hobby equipment", icon: "camera.macro", sortOrder: 45),
        RemoteCategory(id: 46, name: "musical_instruments", displayName: "Musical instruments", icon: "music.note", sortOrder: 46),
        RemoteCategory(id: 47, name: "office_supplies", displayName: "Office supplies", icon: "paperclip", sortOrder: 47),
    ]

    static let defaultCurrencies: [RemoteCurrency] = [
        RemoteCurrency(id: 1, code: "EUR", symbol: "€",  name: "Euro"),
        RemoteCurrency(id: 2, code: "USD", symbol: "$",  name: "US Dollar"),
        RemoteCurrency(id: 3, code: "GBP", symbol: "£",  name: "British Pound"),
        RemoteCurrency(id: 4, code: "DKK", symbol: "kr", name: "Danish Krone"),
        RemoteCurrency(id: 5, code: "SEK", symbol: "kr", name: "Swedish Krona"),
    ]

    private static let categoryGroupDefinitions: [(parent: String, children: [String])] = [
        (
            parent: "furniture_household_fixtures",
            children: [
                "sofas_armchairs",
                "beds_mattresses_wardrobes",
                "dining_tables_chairs",
                "shelving_storage_units",
                "desks_office_chairs",
                "lamps_lighting"
            ]
        ),
        (
            parent: "electronics_appliances",
            children: [
                "tvs_media_systems",
                "laptops_desktops_tablets",
                "smartphones_smartwatches",
                "kitchen_appliances",
                "washing_machine_dryer",
                "gaming_consoles",
                "routers_networking_equipment"
            ]
        ),
        (
            parent: "personal_valuables",
            children: [
                "jewelry",
                "watches",
                "designer_bags",
                "cash",
                "collectibles"
            ]
        ),
        (
            parent: "clothing_personal_items",
            children: [
                "clothing",
                "shoes_outerwear",
                "sports_equipment",
                "bags_luggage"
            ]
        ),
        (
            parent: "kitchenware_household_goods",
            children: [
                "pots_pans_utensils",
                "plates_glasses_cutlery",
                "small_appliances",
                "food_storage",
                "cleaning_equipment"
            ]
        ),
        (
            parent: "art_decor_documents",
            children: [
                "artwork",
                "decor_items",
                "books",
                "important_documents"
            ]
        ),
        (
            parent: "outdoor_items",
            children: [
                "garden_furniture",
                "tools_equipment",
                "bicycles",
                "bbq_grill"
            ]
        ),
        (
            parent: "miscellaneous",
            children: [
                "toys",
                "hobby_equipment",
                "musical_instruments",
                "office_supplies"
            ]
        )
    ]

    private static let deprecatedCategoryNames: Set<String> = [
        "art",
        "electronics",
        "furniture",
        "jewellery",
        "other"
    ]
}
