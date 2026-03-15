import SwiftUI
import SwiftData

struct VaultListView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigStore.self) private var config
    @Environment(AuthService.self) private var auth
    @Environment(LanguageSettings.self) private var language
    @Query(sort: \Item.createdAt, order: .reverse) private var items: [Item]
    @State private var viewModel = VaultViewModel()
    @State private var showAddItem = false
    @State private var showSettings = false
    @State private var isSyncing = false
    @State private var deleteError: String?

    private var visibleItems: [Item] {
        items.filter { $0.inventoryId == auth.effectiveInventoryId }
    }

    private var filtered: [Item] {
        viewModel.filteredItems(visibleItems)
    }

    var body: some View {
        NavigationStack {
            Group {
                if visibleItems.isEmpty {
                    emptyState
                } else {
                    listContent
                }
            }
            .navigationTitle(L10n.tr("vault.title"))
            .toolbarBackground(.hidden, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(BrandTheme.accentBright)
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddItem = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(BrandTheme.accentBright)
                    }
                }
            }
            .sheet(isPresented: $showAddItem) {
                AddItemView()
            }
            .sheet(isPresented: $showSettings) {
                SettingsView(items: visibleItems) {
                    await auth.refreshUserContext()
                    await syncFromSupabase()
                }
            }
            .alert(L10n.tr("vault.delete_error"), isPresented: .constant(deleteError != nil)) {
                Button(L10n.tr("common.ok")) { deleteError = nil }
            } message: {
                Text(deleteError ?? "")
            }
            .task {
                await auth.refreshUserContext()
                await syncFromSupabase()
            }
            .task(id: auth.effectiveInventoryId) {
                guard auth.isAuthenticated else { return }
                await syncFromSupabase()
            }
            .brandBackground()
        }
    }

    private func syncFromSupabase() async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }

        do {
            let (remoteItems, remotePhotos, remoteDocs) = try await SupabaseDataService.fetchAllUserData(
                inventoryId: auth.effectiveInventoryId
            )
            let localById = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
            let photosByItemId = Dictionary(grouping: remotePhotos, by: \.itemId)
            let docsByItemId = Dictionary(grouping: remoteDocs, by: \.itemId)

            for remote in remoteItems {
                if let localItem = localById[remote.id] {
                    localItem.userId = remote.userId
                    localItem.inventoryId = remote.inventoryId
                    localItem.name = remote.name
                    localItem.category = remote.category
                    localItem.currency = remote.currency
                    localItem.purchasePrice = remote.purchasePrice
                    localItem.estimatedValue = remote.estimatedValue
                    localItem.aiEstimate = remote.aiEstimate
                    localItem.purchaseDate = YearFormatter.date(fromYear: remote.yearPurchased)
                    localItem.serialNumber = remote.serialNumber
                    localItem.notes = remote.notes
                    localItem.createdAt = remote.createdAt
                } else {
                    let item = Item(
                        id: remote.id,
                        userId: remote.userId,
                        inventoryId: remote.inventoryId,
                        name: remote.name,
                        category: remote.category,
                        currency: remote.currency,
                        purchasePrice: remote.purchasePrice,
                        estimatedValue: remote.estimatedValue,
                        aiEstimate: remote.aiEstimate,
                        purchaseDate: YearFormatter.date(fromYear: remote.yearPurchased),
                        serialNumber: remote.serialNumber,
                        notes: remote.notes,
                        createdAt: remote.createdAt
                    )
                    modelContext.insert(item)

                    // Download and insert photos for this item
                    let photos = photosByItemId[remote.id] ?? []
                    for rp in photos {
                        if let imageData = try? await SupabaseDataService.downloadFile(path: rp.storagePath) {
                            let photo = ItemPhoto(id: rp.id, imageData: imageData, storagePath: rp.storagePath, capturedAt: rp.capturedAt)
                            photo.item = item
                            modelContext.insert(photo)
                            item.photos.append(photo)
                        }
                    }

                    // Download and insert documents for this item
                    let docs = docsByItemId[remote.id] ?? []
                    for rd in docs {
                        if let fileData = try? await SupabaseDataService.downloadFile(path: rd.storagePath) {
                            let document = ItemDocument(id: rd.id, filename: rd.filename, fileData: fileData, storagePath: rd.storagePath, addedAt: rd.addedAt)
                            document.item = item
                            modelContext.insert(document)
                            item.documents.append(document)
                        }
                    }
                }
            }

            let remoteIds = Set(remoteItems.map(\.id))
            for localItem in items {
                if localItem.inventoryId == auth.effectiveInventoryId, !remoteIds.contains(localItem.id) {
                    modelContext.delete(localItem)
                }
            }
        } catch {
            // Sync errors are non-fatal — local cache still works
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "archivebox")
                .font(.system(size: 72))
                .foregroundStyle(BrandTheme.accentGradient)
            Text(L10n.tr("vault.empty_title"))
                .font(.system(.title2, design: .serif, weight: .bold))
                .foregroundStyle(BrandTheme.textPrimary)
            Text(L10n.tr("vault.empty_message"))
                .font(.subheadline)
                .foregroundStyle(BrandTheme.textSecondary)
                .multilineTextAlignment(.center)
            Button {
                showAddItem = true
            } label: {
                Label(L10n.tr("vault.add_first_item"), systemImage: "plus")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(BrandTheme.accentGradient)
                    .foregroundStyle(BrandTheme.backgroundBottom)
                    .clipShape(Capsule())
            }
            .padding(.top, 8)
        }
        .padding()
        .brandCard()
        .padding()
    }

    private var listContent: some View {
        List {
            summaryHeader
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)

            if !visibleItems.isEmpty {
                Section {
                    ForEach(filtered) { item in
                        NavigationLink(destination: ItemDetailView(item: item)) {
                            ItemRow(item: item)
                        }
                    }
                    .onDelete { offsets in
                        let sourceItems = filtered
                        let itemsToDelete = offsets.map { sourceItems[$0] }
                        Task {
                            for item in itemsToDelete {
                                do {
                                    // Collect storage paths to delete files
                                    let filePaths = item.photos.map(\.storagePath) + item.documents.map(\.storagePath)
                                    let nonEmpty = filePaths.filter { !$0.isEmpty }
                                    if !nonEmpty.isEmpty {
                                        try? await SupabaseDataService.deleteFiles(paths: nonEmpty)
                                    }
                                    // Delete item from Supabase (cascades photos/docs records)
                                    try await SupabaseDataService.deleteItem(id: item.id)
                                    // Delete locally
                                    modelContext.delete(item)
                                } catch {
                                    deleteError = error.localizedDescription
                                }
                            }
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .listStyle(.insetGrouped)
        .searchable(text: $viewModel.searchText, prompt: L10n.tr("vault.search_prompt"))
        .background(Color.clear)
    }

    private var summaryHeader: some View {
        HStack(spacing: 0) {
            StatCard(
                title: L10n.tr("vault.stat.items"),
                value: "\(visibleItems.count)",
                icon: "archivebox.fill"
            )
            Divider().frame(height: 50)
            StatCard(
                title: L10n.tr("vault.stat.total_value"),
                value: CurrencyFormatter.format(
                    viewModel.totalDeclaredValue(visibleItems),
                    code: config.defaultCurrencyCode,
                    symbol: config.currency(code: config.defaultCurrencyCode)?.symbol
                ),
                icon: "eurosign.circle.fill"
            )
            Divider().frame(height: 50)
            StatCard(
                title: L10n.tr("vault.stat.documented"),
                value: "\(viewModel.documentedCount(visibleItems))/\(visibleItems.count)",
                icon: "checkmark.seal.fill"
            )
        }
        .padding(.vertical, 8)
        .background(BrandTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(BrandTheme.border, lineWidth: 1)
        )
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
                .foregroundStyle(BrandTheme.accentGradient)
                .font(.title3)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .foregroundStyle(BrandTheme.textPrimary)
            Text(title)
                .font(.caption2)
                .foregroundStyle(BrandTheme.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
    }
}

struct ItemRow: View {
    @Environment(AppConfigStore.self) private var config

    let item: Item

    var body: some View {
        HStack(spacing: 12) {
            if let photo = item.photos.first {
                CachedDataImage(data: photo.imageData, cacheKey: photo.id.uuidString, maxDimension: 48)
                    .frame(width: 48, height: 48)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(BrandTheme.surface)
                    .frame(width: 48, height: 48)
                    .overlay {
                        Image(systemName: item.categoryIcon)
                            .foregroundStyle(BrandTheme.accentGradient)
                    }
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(item.name)
                    .font(.headline)
                    .lineLimit(1)
                HStack(spacing: 6) {
                    CategoryBadge(category: item.category)
                    Text(CurrencyFormatter.format(item.estimatedValue, for: item, config: config))
                        .font(.subheadline)
                        .foregroundStyle(BrandTheme.textSecondary)
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
        Text(L10n.categoryName(category))
            .font(.caption2).bold()
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(BrandTheme.surface)
            .foregroundStyle(BrandTheme.accentBright)
            .clipShape(Capsule())
    }
}
