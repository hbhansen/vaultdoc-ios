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
                let value = try await AnthropicService.estimateValue(
                    name: item.name,
                    category: item.category,
                    purchasePrice: item.purchasePrice,
                    year: item.yearPurchased
                )
                item.aiEstimate = value

                // Persist AI estimate to Supabase
                let payload = ItemPayload(
                    id: item.id,
                    userId: item.userId,
                    name: item.name,
                    category: item.category,
                    currency: item.currency,
                    purchasePrice: item.purchasePrice,
                    estimatedValue: item.estimatedValue,
                    aiEstimate: value,
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
