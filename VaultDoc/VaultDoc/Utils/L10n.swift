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
        case "furniture_household_fixtures":
            return tr("category.furniture_household_fixtures")
        case "electronics_appliances":
            return tr("category.electronics_appliances")
        case "personal_valuables":
            return tr("category.personal_valuables")
        case "clothing_personal_items":
            return tr("category.clothing_personal_items")
        case "kitchenware_household_goods":
            return tr("category.kitchenware_household_goods")
        case "art_decor_documents":
            return tr("category.art_decor_documents")
        case "outdoor_items":
            return tr("category.outdoor_items")
        case "miscellaneous":
            return tr("category.miscellaneous")
        case "sofas_armchairs":
            return tr("category.sofas_armchairs")
        case "beds_mattresses_wardrobes":
            return tr("category.beds_mattresses_wardrobes")
        case "dining_tables_chairs":
            return tr("category.dining_tables_chairs")
        case "shelving_storage_units":
            return tr("category.shelving_storage_units")
        case "desks_office_chairs":
            return tr("category.desks_office_chairs")
        case "lamps_lighting":
            return tr("category.lamps_lighting")
        case "tvs_media_systems":
            return tr("category.tvs_media_systems")
        case "laptops_desktops_tablets":
            return tr("category.laptops_desktops_tablets")
        case "smartphones_smartwatches":
            return tr("category.smartphones_smartwatches")
        case "kitchen_appliances":
            return tr("category.kitchen_appliances")
        case "washing_machine_dryer":
            return tr("category.washing_machine_dryer")
        case "gaming_consoles":
            return tr("category.gaming_consoles")
        case "routers_networking_equipment":
            return tr("category.routers_networking_equipment")
        case "jewelry":
            return tr("category.jewelry")
        case "jewellery":
            return tr("category.jewellery")
        case "watches":
            return tr("category.watches")
        case "designer_bags":
            return tr("category.designer_bags")
        case "cash":
            return tr("category.cash")
        case "art":
            return tr("category.art")
        case "clothing":
            return tr("category.clothing")
        case "shoes_outerwear":
            return tr("category.shoes_outerwear")
        case "sports_equipment":
            return tr("category.sports_equipment")
        case "bags_luggage":
            return tr("category.bags_luggage")
        case "pots_pans_utensils":
            return tr("category.pots_pans_utensils")
        case "plates_glasses_cutlery":
            return tr("category.plates_glasses_cutlery")
        case "small_appliances":
            return tr("category.small_appliances")
        case "food_storage":
            return tr("category.food_storage")
        case "cleaning_equipment":
            return tr("category.cleaning_equipment")
        case "artwork":
            return tr("category.artwork")
        case "decor_items":
            return tr("category.decor_items")
        case "books":
            return tr("category.books")
        case "important_documents":
            return tr("category.important_documents")
        case "garden_furniture":
            return tr("category.garden_furniture")
        case "tools_equipment":
            return tr("category.tools_equipment")
        case "bicycles":
            return tr("category.bicycles")
        case "bbq_grill":
            return tr("category.bbq_grill")
        case "toys":
            return tr("category.toys")
        case "hobby_equipment":
            return tr("category.hobby_equipment")
        case "musical_instruments":
            return tr("category.musical_instruments")
        case "office_supplies":
            return tr("category.office_supplies")
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
