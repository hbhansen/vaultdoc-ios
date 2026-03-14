import SwiftUI
import SwiftData

@Observable
class VaultViewModel {
    var searchText = ""
    var selectedCategory: String? = nil

    func filteredItems(_ items: [Item]) -> [Item] {
        items.filter { item in
            let matchesSearch = searchText.isEmpty ||
                item.name.localizedCaseInsensitiveContains(searchText)
            let matchesCategory = selectedCategory == nil ||
                item.category == selectedCategory
            return matchesSearch && matchesCategory
        }
    }

    func totalDeclaredValue(_ items: [Item]) -> Double {
        items.reduce(0) { $0 + $1.estimatedValue }
    }

    func documentedCount(_ items: [Item]) -> Int {
        items.filter(\.isDocumented).count
    }

    func deleteItems(offsets: IndexSet, from items: [Item], context: ModelContext) {
        for index in offsets {
            context.delete(items[index])
        }
    }
}
