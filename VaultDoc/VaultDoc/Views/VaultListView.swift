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
            .safeAreaInset(edge: .bottom) {
                bottomAction
                    .padding(.horizontal, 20)
                    .padding(.bottom, 12)
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
        VStack(spacing: 18) {
            Spacer()

            SectionCard(
                title: L10n.tr("vault.empty_title"),
                subtitle: L10n.tr("vault.empty_message")
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    Label(L10n.tr("Stored securely"), systemImage: "lock.shield")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(BrandTheme.textSecondary)

                    Label(L10n.tr("Add the first object to start documenting ownership."), systemImage: "plus.circle")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(BrandTheme.textSecondary)
                }
            }
            .padding(.horizontal, 20)

            Spacer()
        }
    }

    private var listContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                summarySection

                if filtered.isEmpty {
                    SectionCard(
                        title: L10n.tr("No matching items"),
                        subtitle: L10n.tr("Try a different search term.")
                    ) {}
                } else {
                    LazyVStack(spacing: 12) {
                        ForEach(filtered) { item in
                            NavigationLink(destination: ItemDetailView(item: item)) {
                                VaultItemRow(
                                    item: item,
                                    valueText: CurrencyFormatter.format(item.valuationAmount, for: item, config: config)
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    Task {
                                        await delete(item: item)
                                    }
                                } label: {
                                    Label(L10n.tr("Delete"), systemImage: "trash")
                                }
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 12)
            .padding(.bottom, 100)
        }
        .searchable(text: $viewModel.searchText, prompt: L10n.tr("vault.search_prompt"))
    }

    private var summarySection: some View {
        SectionCard(
            title: L10n.tr("Overview"),
            subtitle: L10n.tr("Your records are stored securely and ready when needed.")
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 12) {
                    ValueBadge(
                        title: L10n.tr("vault.stat.items"),
                        value: "\(visibleItems.count)"
                    )
                    ValueBadge(
                        title: L10n.tr("vault.stat.documented"),
                        value: "\(viewModel.documentedCount(visibleItems))/\(visibleItems.count)",
                        tone: .positive
                    )
                }

                ValueBadge(
                    title: L10n.tr("vault.stat.total_value"),
                    value: CurrencyFormatter.format(
                        viewModel.totalDeclaredValue(visibleItems),
                        code: config.defaultCurrencyCode,
                        symbol: config.currency(code: config.defaultCurrencyCode)?.symbol
                    )
                )

                summaryStatusRow
            }
        }
    }

    private var summaryStatusRow: some View {
        HStack(spacing: 10) {
            Label(
                isSyncing ? L10n.tr("Syncing") : L10n.tr("Encrypted"),
                systemImage: isSyncing ? "arrow.triangle.2.circlepath" : "lock.shield"
            )

            Text(L10n.tr("•"))
                .foregroundStyle(BrandTheme.textSecondary)

            Label(
                auth.isAuthenticated ? L10n.tr("Secure access") : L10n.tr("Offline"),
                systemImage: auth.isAuthenticated ? "checkmark.shield" : "wifi.slash"
            )
        }
        .font(.system(size: 14, weight: .semibold))
        .foregroundStyle(BrandTheme.textSecondary)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(BrandTheme.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(BrandTheme.border, lineWidth: 1)
                )
        )
    }

    private var bottomAction: some View {
        Button {
            showAddItem = true
        } label: {
            Label(visibleItems.isEmpty ? L10n.tr("vault.add_first_item") : L10n.tr("Add object"), systemImage: "plus")
        }
        .buttonStyle(PrimaryActionButtonStyle())
    }

    private func delete(item: Item) async {
        do {
            let filePaths = item.photos.map(\.storagePath) + item.documents.map(\.storagePath)
            let nonEmpty = filePaths.filter { !$0.isEmpty }
            if !nonEmpty.isEmpty {
                try? await SupabaseDataService.deleteFiles(paths: nonEmpty)
            }
            try await SupabaseDataService.deleteItem(id: item.id)
            modelContext.delete(item)
        } catch {
            deleteError = error.localizedDescription
        }
    }
}
