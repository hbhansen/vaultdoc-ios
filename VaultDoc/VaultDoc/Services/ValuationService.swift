import Foundation

struct ValuationService {
    struct Input: Sendable {
        let name: String
        let category: String
        let currency: String
        let countryCode: String
        let purchasePrice: Double
        let purchaseDate: Date
        let serialNumber: String
        let notes: String
        let photoCount: Int
        let documentCount: Int
        let photoData: [Data]

        init(
            name: String,
            category: String,
            currency: String,
            countryCode: String,
            purchasePrice: Double,
            purchaseDate: Date,
            serialNumber: String,
            notes: String,
            photoCount: Int,
            documentCount: Int,
            photoData: [Data] = []
        ) {
            self.name = name
            self.category = category
            self.currency = currency
            self.countryCode = countryCode
            self.purchasePrice = purchasePrice
            self.purchaseDate = purchaseDate
            self.serialNumber = serialNumber
            self.notes = notes
            self.photoCount = photoCount
            self.documentCount = documentCount
            self.photoData = photoData
        }

        init(item: Item) {
            self.init(
                name: item.name,
                category: item.category,
                currency: item.currency,
                countryCode: defaultCountryCode,
                purchasePrice: item.purchasePrice,
                purchaseDate: item.purchaseDate,
                serialNumber: item.serialNumber,
                notes: item.notes,
                photoCount: item.photos.count,
                documentCount: item.documents.count,
                photoData: item.photos.map(\.imageData)
            )
        }
    }

    struct Result: Sendable {
        let amount: Double
        let currency: String
        let source: Source
        let confidence: Confidence
        let identifiedObject: String?
        let make: String?
        let model: String?
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
        if ValuationRules.remoteValuationEnabled, ChatGPTService.isConfigured, !input.photoData.isEmpty {
            do {
                let assessment = try await ChatGPTService.valuateObject(
                    nameHint: input.name,
                    categoryHint: input.category,
                    purchasePrice: input.purchasePrice,
                    purchaseDate: input.purchaseDate,
                    currency: input.currency,
                    countryCode: input.countryCode,
                    photos: input.photoData
                )
                return Result(
                    amount: roundedCurrency(assessment.amount),
                    currency: input.currency,
                    source: .ai,
                    confidence: confidence(for: input),
                    identifiedObject: assessment.identifiedObject,
                    make: assessment.make,
                    model: assessment.model
                )
            } catch let error as ChatGPTError where error == .unsupportedSubject {
                throw error
            } catch {
                return heuristicValuation(for: input)
            }
        }

        if ValuationRules.remoteValuationEnabled, ChatGPTService.isConfigured {
            do {
                let amountText = try await ChatGPTService.sendMessage(
                    ValuationRules.textOnlyValuationPrompt(
                        name: input.name,
                        category: input.category,
                        currency: input.currency,
                        purchasePrice: input.purchasePrice,
                        purchaseDate: input.purchaseDate
                    )
                )
                guard let amount = Double(amountText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
                    throw ChatGPTError.parseError
                }
                return Result(
                    amount: amount,
                    currency: input.currency,
                    source: .ai,
                    confidence: confidence(for: input),
                    identifiedObject: nil,
                    make: nil,
                    model: nil
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

        let categoryRule = ValuationRules.categoryRule(for: normalizedCategory)
        let agedValue = purchasePrice * pow(categoryRule.annualFactor, Double(age))
        let documentationMultiplier = 1 + documentationScore(for: input) * ValuationRules.documentationValueBoost
        let noteMultiplier = input.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1.0 : ValuationRules.notesMultiplier
        let serialMultiplier = input.serialNumber.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? 1.0 : ValuationRules.serialNumberMultiplier

        let rawValue = agedValue * documentationMultiplier * noteMultiplier * serialMultiplier
        let floorValue = purchasePrice * categoryRule.floorFactor
        let fallbackBaseline = categoryRule.baselineValue
        let amount = max(rawValue, floorValue, fallbackBaseline) * ValuationRules.countryMultiplier(for: input.countryCode)

        return Result(
            amount: roundedCurrency(amount),
            currency: input.currency,
            source: .heuristic,
            confidence: confidence(for: input),
            identifiedObject: nil,
            make: nil,
            model: nil
        )
    }

    private static func documentationScore(for input: Input) -> Double {
        let photoScore = min(Double(input.photoCount) / 3, 1)
        let documentScore = min(Double(input.documentCount) / 2, 1)
        return (photoScore * ValuationRules.documentationPhotoWeight)
            + (documentScore * ValuationRules.documentationDocumentWeight)
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

    private static var defaultCountryCode: String {
        ValuationRules.defaultCountryCode
    }
}
