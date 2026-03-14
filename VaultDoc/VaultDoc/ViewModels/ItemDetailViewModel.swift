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
