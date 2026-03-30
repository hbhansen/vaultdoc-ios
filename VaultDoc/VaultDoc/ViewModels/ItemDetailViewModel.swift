import SwiftUI
import SwiftData

@Observable
class ItemDetailViewModel {
    var isRequestingEstimate = false
    var estimateError: String? = nil
    var showShareSheet = false
    var pdfData: Data? = nil

    func requestAIEstimate(for item: Item) {
        isRequestingEstimate = true
        estimateError = nil
        Task {
            do {
                let valuation = try await ValuationService.valuate(item: item)
                item.aiEstimate = valuation.amount

                // Persist AI estimate to Supabase
                let payload = ItemPayload(
                    id: item.id,
                    userId: item.userId,
                    inventoryId: item.inventoryId,
                    name: item.name,
                    category: item.category,
                    currency: item.currency,
                    purchasePrice: item.purchasePrice,
                    estimatedValue: item.estimatedValue,
                    aiEstimate: valuation.amount,
                    yearPurchased: item.yearPurchased,
                    serialNumber: item.serialNumber,
                    notes: item.notes,
                    createdAt: item.createdAt
                )
                _ = try? await SupabaseDataService.updateItem(id: item.id, payload)
            } catch {
                estimateError = error.localizedDescription
            }
            isRequestingEstimate = false
        }
    }

    func generatePDF(for item: Item) {
        pdfData = PDFGenerator.generate(for: item)
        showShareSheet = true
    }
}
