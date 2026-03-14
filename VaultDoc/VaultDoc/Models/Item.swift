import Foundation
import SwiftData

@Model
final class Item {
    var id: UUID
    var name: String
    var category: String
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
        name: String,
        category: String = "other",
        purchasePrice: Double = 0,
        estimatedValue: Double = 0,
        aiEstimate: Double? = nil,
        yearPurchased: Int = Calendar.current.component(.year, from: Date()),
        serialNumber: String = "",
        notes: String = "",
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.category = category
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

    static let categories = [
        "jewellery", "art", "electronics", "furniture", "collectibles", "other"
    ]

    var categoryDisplayName: String {
        category.prefix(1).uppercased() + category.dropFirst()
    }

    var categoryIcon: String {
        switch category {
        case "jewellery": return "sparkles"
        case "art": return "paintpalette"
        case "electronics": return "desktopcomputer"
        case "furniture": return "sofa"
        case "collectibles": return "star"
        default: return "archivebox"
        }
    }
}

@Model
final class ItemPhoto {
    var id: UUID
    var imageData: Data
    var capturedAt: Date
    var item: Item?

    init(id: UUID = UUID(), imageData: Data, capturedAt: Date = Date()) {
        self.id = id
        self.imageData = imageData
        self.capturedAt = capturedAt
    }
}

@Model
final class ItemDocument {
    var id: UUID
    var filename: String
    var fileData: Data
    var fileSize: Int
    var addedAt: Date
    var item: Item?

    init(id: UUID = UUID(), filename: String, fileData: Data, addedAt: Date = Date()) {
        self.id = id
        self.filename = filename
        self.fileData = fileData
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
