import Foundation
import Testing
@testable import VaultDoc

struct VaultDocTests {
    @Test func itemComputedPropertiesReflectUnderlyingData() {
        let purchaseDate = Calendar.current.date(from: DateComponents(year: 2022, month: 6, day: 15))!
        let item = Item(
            name: "Desk Lamp",
            category: "electronics",
            currency: "USD",
            purchasePrice: 120,
            estimatedValue: 80,
            aiEstimate: 95,
            purchaseDate: purchaseDate
        )
        item.photos = [ItemPhoto(imageData: Data([0x01, 0x02]))]
        item.documents = [ItemDocument(filename: "receipt.pdf", fileData: Data([0x03, 0x04]))]

        #expect(item.isDocumented)
        #expect(item.yearPurchased == 2022)
        #expect(item.valuationAmount == 95)
        #expect(item.categoryIcon == "desktopcomputer")
    }

    @Test func itemFallsBackToEstimatedValueWhenNoAIValueExists() {
        let item = Item(
            name: "Painting",
            category: "art",
            estimatedValue: 2_500
        )

        #expect(item.valuationAmount == 2_500)
        #expect(!item.isDocumented)
        #expect(item.categoryIcon == "paintpalette")
    }

    @Test func itemDocumentFormattedSizeMatchesStoredDataSize() {
        let fileData = Data(repeating: 0xFF, count: 2_048)
        let document = ItemDocument(filename: "manual.pdf", fileData: fileData)

        #expect(document.fileSize == 2_048)
        #expect(document.formattedSize == ByteCountFormatter.string(fromByteCount: 2_048, countStyle: .file))
    }

    @Test func yearFormatterRoundTripsBetweenYearAndDate() {
        let date = YearFormatter.date(fromYear: 2018)

        #expect(YearFormatter.year(from: date) == 2018)
    }

    @Test func valuationRulesReturnExpectedCategoryAndCountryAdjustments() {
        let electronics = ValuationRules.categoryRule(for: "electronics")
        let defaultRule = ValuationRules.categoryRule(for: "unknown")

        #expect(electronics.annualFactor == 0.85)
        #expect(electronics.floorFactor == 0.20)
        #expect(electronics.baselineValue == 150)
        #expect(defaultRule.baselineValue == 100)
        #expect(ValuationRules.countryMultiplier(for: "ch") == 1.12)
        #expect(ValuationRules.countryMultiplier(for: "US") == 1.05)
        #expect(ValuationRules.countryMultiplier(for: "DE") == 1.0)
    }

    @Test func textOnlyValuationPromptIncludesRelevantItemContext() {
        let purchaseDate = Calendar.current.date(from: DateComponents(year: 2021, month: 1, day: 1))!
        let prompt = ValuationRules.textOnlyValuationPrompt(
            name: "Rolex",
            category: "jewellery",
            currency: "USD",
            purchasePrice: 5_000,
            purchaseDate: purchaseDate
        )

        #expect(prompt.contains("Name: Rolex"))
        #expect(prompt.contains("Category: jewellery"))
        #expect(prompt.contains("Purchase price: USD 5000.0"))
        #expect(prompt.contains("Year purchased: 2021"))
        #expect(prompt.contains("Reply with ONLY a number"))
    }
}
