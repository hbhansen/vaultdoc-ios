import Foundation
import Testing
@testable import VaultDoc

struct ValuationServiceTests {
    @Test func electronicsDepreciateButStayAboveFloor() {
        let input = ValuationService.Input(
            name: "Laptop",
            category: "electronics",
            currency: "EUR",
            purchasePrice: 2_000,
            purchaseDate: Calendar.current.date(from: DateComponents(year: 2021, month: 1, day: 1))!,
            serialNumber: "",
            notes: "",
            photoCount: 0,
            documentCount: 0
        )

        let result = ValuationService.heuristicValuation(for: input)

        #expect(result.source == .heuristic)
        #expect(result.currency == "EUR")
        #expect(result.amount >= 400)
        #expect(result.amount < 2_000)
        #expect(result.confidence == .medium)
    }

    @Test func collectiblesGainValueWithDocumentation() {
        let input = ValuationService.Input(
            name: "Signed Trading Card",
            category: "collectibles",
            currency: "EUR",
            purchasePrice: 1_000,
            purchaseDate: Calendar.current.date(from: DateComponents(year: 2023, month: 1, day: 1))!,
            serialNumber: "ABC-123",
            notes: "Limited edition with certificate",
            photoCount: 3,
            documentCount: 2
        )

        let result = ValuationService.heuristicValuation(for: input)

        #expect(result.amount > 1_000)
        #expect(result.confidence == .high)
    }

    @Test func missingPurchasePriceFallsBackToCategoryBaseline() {
        let input = ValuationService.Input(
            name: "Unknown Painting",
            category: "art",
            currency: "EUR",
            purchasePrice: 0,
            purchaseDate: Calendar.current.date(from: DateComponents(year: 2020, month: 1, day: 1))!,
            serialNumber: "",
            notes: "",
            photoCount: 0,
            documentCount: 0
        )

        let result = ValuationService.heuristicValuation(for: input)

        #expect(result.amount == 500)
        #expect(result.confidence == .low)
    }
}
