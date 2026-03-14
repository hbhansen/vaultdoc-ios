import Foundation
import SwiftData

@Model
final class Item {
    var id: UUID
    var userId: String
    var name: String
    var category: String
    var currency: String
    var purchasePrice: Double
    var estimatedValue: Double
    var aiEstimate: Double?
    var yearPurchased: Int
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
        name: String,
        category: String = "other",
        currency: String = "EUR",
        purchasePrice: Double = 0,
        estimatedValue: Double = 0,
        aiEstimate: Double? = nil,
        yearPurchased: Int = Calendar.current.component(.year, from: Date()),
        serialNumber: String = "",
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.userId = userId
        self.name = name
        self.category = category
        self.currency = currency
        self.purchasePrice = purchasePrice
        self.estimatedValue = estimatedValue
        self.aiEstimate = aiEstimate
        self.yearPurchased = yearPurchased
        self.serialNumber = serialNumber
        self.notes = notes
        self.createdAt = createdAt
        self.photos = []
        self.documents = []
    }

    var isDocumented: Bool {
        !photos.isEmpty && !documents.isEmpty
    }

    var categoryDisplayName: String {
        category.prefix(1).uppercased() + category.dropFirst()
    }

    var categoryIcon: String {
        switch category {
        case "jewellery":   return "sparkles"
        case "art":         return "paintpalette"
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
        let kb = Double(fileSize) / 1024
        if kb < 1024 {
            return String(format: "%.1f KB", kb)
        }
        return String(format: "%.1f MB", kb / 1024)
    }
}
