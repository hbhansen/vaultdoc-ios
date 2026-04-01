import Foundation
import SwiftData

@Model
final class Item {
    var id: UUID
    var userId: String
    var inventoryId: String
    var name: String
    var category: String
    var currency: String
    var purchasePrice: Double
    var estimatedValue: Double
    var aiEstimate: Double?
    var purchaseDate: Date
    var serialNumber: String
    var notes: String
    var createdAt: Date

    @Relationship(deleteRule: .cascade, inverse: \ItemPhoto.item)
    var photos: [ItemPhoto]

    @Relationship(deleteRule: .cascade, inverse: \ItemDocument.item)
    var documents: [ItemDocument]

    init(
        id: UUID = UUID(),
        userId: String = "",
        inventoryId: String = "",
        name: String,
        category: String = "miscellaneous",
        currency: String = "EUR",
        purchasePrice: Double = 0,
        estimatedValue: Double = 0,
        aiEstimate: Double? = nil,
        purchaseDate: Date = YearFormatter.currentDate,
        serialNumber: String = "",
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.inventoryId = inventoryId
        self.name = name
        self.category = category
        self.currency = currency
        self.purchasePrice = purchasePrice
        self.estimatedValue = estimatedValue
        self.aiEstimate = aiEstimate
        self.purchaseDate = purchaseDate
        self.serialNumber = serialNumber
        self.notes = notes
        self.createdAt = createdAt
        self.photos = []
        self.documents = []
    }

    var isDocumented: Bool {
        !photos.isEmpty && !documents.isEmpty
    }

    var yearPurchased: Int {
        YearFormatter.year(from: purchaseDate)
    }

    var categoryDisplayName: String {
        L10n.categoryName(category)
    }

    var valuationAmount: Double {
        aiEstimate ?? estimatedValue
    }

    var categoryIcon: String {
        switch category {
        case "furniture_household_fixtures": return "sofa"
        case "electronics_appliances": return "desktopcomputer"
        case "personal_valuables": return "sparkles"
        case "clothing_personal_items": return "hanger"
        case "kitchenware_household_goods": return "fork.knife"
        case "art_decor_documents": return "photo.on.rectangle"
        case "outdoor_items": return "bicycle"
        case "miscellaneous": return "archivebox"
        case "sofas_armchairs": return "sofa"
        case "beds_mattresses_wardrobes": return "bed.double"
        case "dining_tables_chairs": return "table.furniture"
        case "shelving_storage_units": return "books.vertical"
        case "desks_office_chairs": return "chair.lounge"
        case "lamps_lighting": return "lamp.floor"
        case "tvs_media_systems": return "tv"
        case "laptops_desktops_tablets": return "laptopcomputer"
        case "smartphones_smartwatches": return "iphone.gen3"
        case "kitchen_appliances": return "oven"
        case "washing_machine_dryer": return "washer"
        case "gaming_consoles": return "gamecontroller"
        case "routers_networking_equipment": return "wifi.router"
        case "jewelry": return "sparkles"
        case "jewellery":   return "sparkles"
        case "watches": return "watch.analog"
        case "designer_bags": return "bag"
        case "cash": return "banknote"
        case "art":         return "paintpalette"
        case "clothing": return "tshirt"
        case "shoes_outerwear": return "shoeprints.fill"
        case "sports_equipment": return "dumbbell"
        case "bags_luggage": return "suitcase"
        case "pots_pans_utensils": return "frying.pan"
        case "plates_glasses_cutlery": return "wineglass"
        case "small_appliances": return "applescript"
        case "food_storage": return "takeoutbag.and.cup.and.straw"
        case "cleaning_equipment": return "spray.bottle"
        case "artwork": return "paintpalette"
        case "decor_items": return "photo"
        case "books": return "books.vertical"
        case "important_documents": return "doc.text"
        case "garden_furniture": return "tree"
        case "tools_equipment": return "hammer"
        case "bicycles": return "bicycle"
        case "bbq_grill": return "flame"
        case "toys": return "figure.play"
        case "hobby_equipment": return "camera.macro"
        case "musical_instruments": return "music.note"
        case "office_supplies": return "paperclip"
        case "electronics": return "desktopcomputer"
        case "furniture":   return "sofa"
        case "collectibles":return "star"
        default:            return "archivebox"
        }
    }
}

@Model
final class ItemPhoto {
    var id: UUID
    var imageData: Data
    var storagePath: String
    var capturedAt: Date
    var item: Item?

    init(id: UUID = UUID(), imageData: Data, storagePath: String = "", capturedAt: Date = Date()) {
        self.id = id
        self.imageData = imageData
        self.storagePath = storagePath
        self.capturedAt = capturedAt
    }
}

@Model
final class ItemDocument {
    var id: UUID
    var filename: String
    var fileData: Data
    var storagePath: String
    var fileSize: Int
    var addedAt: Date
    var item: Item?

    init(id: UUID = UUID(), filename: String, fileData: Data, storagePath: String = "", addedAt: Date = Date()) {
        self.id = id
        self.filename = filename
        self.fileData = fileData
        self.storagePath = storagePath
        self.fileSize = fileData.count
        self.addedAt = addedAt
    }

    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: Int64(fileSize), countStyle: .file)
    }
}
