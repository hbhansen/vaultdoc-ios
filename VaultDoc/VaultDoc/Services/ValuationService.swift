import Foundation

struct ValuationService {
    struct Input: Sendable {
        let name: String
        let category: String
        let currency: String
        let purchasePrice: Double
        let purchaseDate: Date
        let serialNumber: String
        let notes: String
        let photoCount: Int
        let documentCount: Int

        init(
            name: String,
            category: String,
            currency: String,
            purchasePrice: Double,
            purchaseDate: Date,
            serialNumber: String,
            notes: String,
            photoCount: Int,
            documentCount: Int
        ) {
            self.name = name
            self.category = category
            self.currency = currency
            self.purchasePrice = purchasePrice
            self.purchaseDate = purchaseDate
            self.serialNumber = serialNumber
            self.notes = notes
            self.photoCount = photoCount
            self.documentCount = documentCount
        }

        init(item: Item) {
            self.init(
                name: item.name,
                category: item.category,
                currency: item.currency,
                purchasePrice: item.purchasePrice,
                purchaseDate: item.purchaseDate,
                serialNumber: item.serialNumber,
                notes: item.notes,
                photoCount: item.photos.count,
                documentCount: item.documents.count
            )
        }
    }

    struct Result: Sendable {
        let amount: Double
        let currency: String
        let source: Source
        let confidence: Confidence
    }

    enum Source: String, Sendable {
        case ai
        case heuristic
    }

    enum Confidence: String, Sendable {
        case low
        case medium
        case high
    }

    static func valuate(item: Item) async throws -> Result {
        try await valuate(input: Input(item: item))
    }

    static func valuate(input: Input) async throws -> Result {
        if AnthropicService.isConfigured {
            do {
                let amount = try await AnthropicService.estimateValue(
                    name: input.name,
                    category: input.category,
                    purchasePrice: input.purchasePrice,
                    year: YearFormatter.year(from: input.purchaseDate)
                )
                return Result(
                    amount: amount,
                    currency: input.currency,
                    source: .ai,
                    confidence: confidence(for: input)
                )
            } catch {
                return heuristicValuation(for: input)
            }
        }

        return heuristicValuation(for: input)
    }

    static func heuristicValuation(for input: Input) -> Result {
        let currentYear = YearFormatter.year(from: Date())
        let purchaseYear = YearFormatter.year(from: input.purchaseDate)
        let age = max(0, currentYear - purchaseYear)

        let normalizedCategory = input.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let purchasePrice = max(0, input.purchasePrice)

        let categoryRule = depreciationRule(for: normalizedCategory)
        let agedValue = purchasePrice * pow(categoryRule.annualFactor, Double(age))
        let documentationMultiplier = 1 + documentationScore(for: input) * 0.08
        let noteMultiplier = input.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1.0 : 1.03
        let serialMultiplier = input.serialNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1.0 : 1.02

        let rawValue = agedValue * documentationMultiplier * noteMultiplier * serialMultiplier
        let floorValue = purchasePrice * categoryRule.floorFactor
        let fallbackBaseline = baselineValue(for: normalizedCategory)
        let amount = max(rawValue, floorValue, fallbackBaseline)

        return Result(
            amount: roundedCurrency(amount),
            currency: input.currency,
            source: .heuristic,
            confidence: confidence(for: input)
        )
    }

    private static func depreciationRule(for category: String) -> (annualFactor: Double, floorFactor: Double) {
        switch category {
        case "electronics":
            return (0.85, 0.20)
        case "furniture":
            return (0.94, 0.35)
        case "art":
            return (1.04, 0.80)
        case "jewellery":
            return (1.03, 0.85)
        case "collectibles":
            return (1.05, 0.90)
        default:
            return (0.98, 0.50)
        }
    }

    private static func baselineValue(for category: String) -> Double {
        switch category {
        case "electronics":
            return 150
        case "furniture":
            return 300
        case "art":
            return 500
        case "jewellery":
            return 400
        case "collectibles":
            return 250
        default:
            return 100
        }
    }

    private static func documentationScore(for input: Input) -> Double {
        let photoScore = min(Double(input.photoCount) / 3, 1)
        let documentScore = min(Double(input.documentCount) / 2, 1)
        return (photoScore * 0.6) + (documentScore * 0.4)
    }

    private static func confidence(for input: Input) -> Confidence {
        let hasPurchasePrice = input.purchasePrice > 0
        let hasIdentity = !input.serialNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let documentation = documentationScore(for: input)

        if hasPurchasePrice && hasIdentity && documentation >= 0.5 {
            return .high
        }

        if hasPurchasePrice || documentation > 0 {
            return .medium
        }

        return .low
    }

    private static func roundedCurrency(_ amount: Double) -> Double {
        (amount * 100).rounded() / 100
    }
}
