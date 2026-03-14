import SwiftUI
import SwiftData

struct VaultListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigStore.self) private var config
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    @State private var viewModel = VaultViewModel()
    @State private var showAddItem = false
    @State private var showSettings = false

    var filtered: [Item] { viewModel.filteredItems(items) }

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .navigationTitle("My Vault")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddItem = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddItemView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(items: items)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "archivebox")
                .font(.system(size: 72))
                .foregroundStyle(.teal.opacity(0.6))
            Text("Your vault is empty")
                .font(.title2).bold()
            Text("Add your first item to start building\nyour insurance documentation.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showAddItem = true
            } label: {
                Label("Add Your First Item", systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.teal)
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .padding()
    }

    private var listContent: some View {
        List {
            summaryHeader
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

            if !items.isEmpty {
                Section {
                    ForEach(filtered) { item in
                        NavigationLink(destination: ItemDetailView(item: item)) {
                            ItemRow(item: item)
                        }
                    }
                    .onDelete { offsets in
                        let sourceItems = filtered
                        for index in offsets {
                            modelContext.delete(sourceItems[index])
                        }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $viewModel.searchText, prompt: "Search items")
    }

    private var summaryHeader: some View {
        HStack(spacing: 0) {
            StatCard(
                title: "Items",
                value: "\(items.count)",
                icon: "archivebox.fill"
            )
            Divider().frame(height: 50)
            StatCard(
                title: "Total Value",
                value: CurrencyFormatter.format(viewModel.totalDeclaredValue(items)),
                icon: "eurosign.circle.fill"
            )
            Divider().frame(height: 50)
            StatCard(
                title: "Documented",
                value: "\(viewModel.documentedCount(items))/\(items.count)",
                icon: "checkmark.seal.fill"
            )
        }
        .padding(.vertical, 8)
        .background(Color(.secondarySystemGroupedBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}

struct StatCard: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.teal)
                .font(.title3)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

struct ItemRow: View {
    let item: Item

    var body: some View {
        HStack(spacing: 12) {
            if let photo = item.photos.first, let ui = UIImage(data: photo.imageData) {
                Image(uiImage: ui)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.teal.opacity(0.15))
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: item.categoryIcon)
                            .foregroundStyle(.teal)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    CategoryBadge(category: item.category)
                    Text(CurrencyFormatter.format(item.estimatedValue))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Circle()
                .fill(item.isDocumented ? Color.green : Color.orange)
                .frame(width: 8, height: 8)
        }
        .padding(.vertical, 2)
    }
}

struct CategoryBadge: View {
    let category: String

    var body: some View {
        Text(category.prefix(1).uppercased() + category.dropFirst())
            .font(.caption2).bold()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.teal.opacity(0.15))
            .foregroundStyle(.teal)
            .clipShape(Capsule())
    }
}
