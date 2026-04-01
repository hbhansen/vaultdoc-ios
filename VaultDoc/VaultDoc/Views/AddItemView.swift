import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct AddItemView: View {
    enum AddFlowStep: Int, CaseIterable {
        case evidence
        case details
        case review

        var title: String {
            switch self {
            case .evidence:
                return L10n.tr("Evidence")
            case .details:
                return L10n.tr("Details")
            case .review:
                return L10n.tr("Review")
            }
        }

        var subtitle: String {
            switch self {
            case .evidence:
                return L10n.tr("Capture or upload the files that prove ownership.")
            case .details:
                return L10n.tr("Confirm the essential facts for retrieval and claims.")
            case .review:
                return L10n.tr("Check the summary before saving to your vault.")
            }
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigStore.self) private var config
    @Environment(AuthService.self) private var auth
    @Environment(LanguageSettings.self) private var language

    var existingItem: Item? = nil

    @State private var name = ""
    @State private var category = "miscellaneous"
    @State private var currency = ""
    @State private var purchasePrice = ""
    @State private var purchaseDate = YearFormatter.currentDate
    @State private var serialNumber = ""
    @State private var notes = ""
    @State private var valuationAmount: Double?
    @State private var isRequestingValuation = false
    @State private var valuationError: String?
    @State private var valuationTask: Task<Void, Never>?

    @State private var photoItems: [PhotosPickerItem] = []
    @State private var capturedImages: [UIImage] = []
    @State private var showCamera = false
    @State private var showDocumentPicker = false
    @State private var attachedDocuments: [(filename: String, data: Data)] = []

    @State private var isSaving = false
    @State private var saveError: String?
    @State private var currentStep: AddFlowStep = .evidence
    @State private var showCategoryPicker = false

    var isEditing: Bool { existingItem != nil }
    var title: String { isEditing ? L10n.tr("add_item.edit_title") : L10n.tr("add_item.add_title") }

    var selectedCurrency: RemoteCurrency? {
        config.currency(code: currency)
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 20) {
                    stepHeader
                    stepBody

                    if let error = saveError {
                        NoticeBanner(
                            text: error,
                            systemImage: "exclamationmark.triangle.fill",
                            tone: .critical
                        )
                    }

                    if let valuationError {
                        NoticeBanner(
                            text: valuationError,
                            systemImage: "info.circle.fill",
                            tone: .info
                        )
                    }
                }
                .padding(20)
                .padding(.bottom, 28)
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if currentStep != .evidence {
                        Button(L10n.tr("Back")) {
                            retreatStep()
                        }
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(primaryActionTitle) {
                        Task {
                            if currentStep == .review {
                                await saveItem()
                            } else {
                                advanceStep()
                            }
                        }
                    }
                    .disabled(primaryActionDisabled)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { imageData in
                    if let img = UIImage(data: imageData) {
                        capturedImages.append(img)
                        scheduleValuationRefresh()
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView { url in
                    if let data = try? Data(contentsOf: url) {
                        attachedDocuments.append((filename: url.lastPathComponent, data: data))
                        scheduleValuationRefresh()
                    }
                }
            }
            .sheet(isPresented: $showCategoryPicker) {
                CategorySelectionView(
                    groups: config.groupedCategories,
                    selectedCategory: $category
                )
            }
            .onAppear {
                if let item = existingItem {
                    name = item.name
                    category = item.category
                    currency = item.currency
                    purchasePrice = item.purchasePrice > 0 ? String(item.purchasePrice) : ""
                    valuationAmount = item.valuationAmount > 0 ? item.valuationAmount : nil
                    purchaseDate = item.purchaseDate
                    serialNumber = item.serialNumber
                    notes = item.notes
                    scheduleValuationRefresh()
                } else {
                    currency = config.defaultCurrencyCode
                    purchaseDate = YearFormatter.currentDate
                    valuationAmount = nil
                }
            }
            .onChange(of: config.defaultCurrencyCode) { _, newCode in
                guard !newCode.isEmpty else { return }
                currency = newCode
                scheduleValuationRefresh()
            }
            .onChange(of: purchaseDate) { _, _ in
                scheduleValuationRefresh()
            }
            .onChange(of: purchasePrice) { _, _ in
                scheduleValuationRefresh()
            }
            .onChange(of: category) { _, _ in
                scheduleValuationRefresh()
            }
            .onChange(of: name) { _, _ in
                scheduleValuationRefresh()
            }
        }
        .onChange(of: photoItems) { _, newItems in
            Task {
                for item in newItems {
                    if let data = try? await item.loadTransferable(type: Data.self),
                       let img = UIImage(data: data) {
                        capturedImages.append(img)
                    }
                }
                photoItems = []
                scheduleValuationRefresh()
            }
        }
        .brandBackground()
    }

    private var stepHeader: some View {
        SectionCard(
            title: currentStep.title,
            subtitle: currentStep.subtitle
        ) {
            HStack(spacing: 12) {
                ForEach(AddFlowStep.allCases, id: \.rawValue) { step in
                    ValueBadge(
                        title: L10n.format("Step %lld", Int64(step.rawValue + 1)),
                        value: step.title,
                        tone: step == currentStep ? .positive : .neutral
                    )
                }
            }

        }
    }

    @ViewBuilder
    private var stepBody: some View {
        switch currentStep {
        case .evidence:
            evidenceStep
        case .details:
            detailsStep
        case .review:
            reviewStep
        }
    }

    private var evidenceStep: some View {
        VStack(spacing: 20) {
            SectionCard(
                title: L10n.tr("Capture or upload"),
                subtitle: L10n.tr("Add photos first. Documents can be attached before saving.")
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        Button {
                            showCamera = true
                        } label: {
                            Label(L10n.tr("add_item.camera"), systemImage: "camera")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(PrimaryActionButtonStyle())

                        PhotosPicker(selection: $photoItems, maxSelectionCount: 10, matching: .images) {
                            Label(L10n.tr("add_item.library"), systemImage: "photo.on.rectangle")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(BrandTheme.surfaceElevated)
                                )
                                .foregroundStyle(BrandTheme.textPrimary)
                        }
                    }

                    if !capturedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(capturedImages.enumerated()), id: \.offset) { idx, img in
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 88, height: 88)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .overlay(alignment: .topTrailing) {
                                            Button {
                                                capturedImages.remove(at: idx)
                                                scheduleValuationRefresh()
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(BrandTheme.actionForeground)
                                                    .background(BrandTheme.backgroundPrimary.opacity(0.72), in: Circle())
                                            }
                                            .padding(6)
                                        }
                                }
                            }
                        }
                    }

                    HStack(spacing: 12) {
                        ValueBadge(title: L10n.tr("Photos"), value: "\(capturedImages.count + (existingItem?.photos.count ?? 0))")
                        ValueBadge(title: L10n.tr("Documents"), value: "\(attachedDocuments.count + (existingItem?.documents.count ?? 0))")
                    }
                }
            }

            SectionCard(
                title: L10n.tr("item_detail.documents"),
                subtitle: L10n.tr("Receipts, certificates, and manuals improve proof quality.")
            ) {
                VStack(alignment: .leading, spacing: 12) {
                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label(L10n.tr("add_item.attach_document"), systemImage: "doc.badge.plus")
                    }
                    .buttonStyle(PrimaryActionButtonStyle())

                    if attachedDocuments.isEmpty {
                        Text(L10n.tr("No new documents attached."))
                            .font(.system(size: 15))
                            .foregroundStyle(BrandTheme.textSecondary)
                    } else {
                        ForEach(Array(attachedDocuments.enumerated()), id: \.offset) { idx, doc in
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(doc.filename)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(BrandTheme.textPrimary)
                                    Text(ByteCountFormatter.string(fromByteCount: Int64(doc.data.count), countStyle: .file))
                                        .font(.system(size: 14))
                                        .foregroundStyle(BrandTheme.textSecondary)
                                }
                                Spacer()
                                Button(role: .destructive) {
                                    attachedDocuments.remove(at: idx)
                                    scheduleValuationRefresh()
                                } label: {
                                    Image(systemName: "trash")
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    private var detailsStep: some View {
        VStack(spacing: 20) {
            SectionCard(
                title: L10n.tr("Essential details"),
                subtitle: L10n.tr("Only record what helps identification and value.")
            ) {
                VStack(alignment: .leading, spacing: 14) {
                    labeledField(L10n.tr("Object name")) {
                        TextField(L10n.tr("item.field.name"), text: $name)
                            .brandInputField()
                    }

                    labeledField(L10n.tr("item.field.category")) {
                        Button {
                            showCategoryPicker = true
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: selectedCategoryIcon)
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(BrandTheme.accentBright)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(selectedCategoryTitle)
                                        .font(.system(size: 16, weight: .medium))
                                        .foregroundStyle(BrandTheme.textPrimary)
                                    if let selectedCategorySubtitle {
                                        Text(selectedCategorySubtitle)
                                            .font(.system(size: 13, weight: .medium))
                                            .foregroundStyle(BrandTheme.textSecondary)
                                    }
                                }

                                Spacer()

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(BrandTheme.textSecondary)
                            }
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 16, style: .continuous)
                                    .fill(BrandTheme.surfaceElevated)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                                            .stroke(BrandTheme.border, lineWidth: 1)
                                    )
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 12) {
                        labeledField(L10n.tr("item.field.currency")) {
                            Text("\(selectedCurrency?.symbol ?? "€")  \(currency)")
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .brandInputField()
                        }

                        labeledField(L10n.tr("item.field.purchase_price")) {
                            TextField(L10n.tr("item.field.purchase_price"), text: $purchasePrice)
                                .keyboardType(.decimalPad)
                                .brandInputField()
                        }
                    }

                    DatePicker(
                        L10n.tr("item.field.year_purchased"),
                        selection: $purchaseDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )

                    labeledField(L10n.tr("item.field.serial_number")) {
                        TextField(L10n.tr("item.field.serial_number"), text: $serialNumber)
                            .brandInputField()
                    }

                    labeledField(L10n.tr("item.field.notes")) {
                        TextField(L10n.tr("item.field.notes"), text: $notes, axis: .vertical)
                            .lineLimit(4, reservesSpace: true)
                            .brandInputField()
                    }
                }
            }
        }
    }

    private var reviewStep: some View {
        VStack(spacing: 20) {
            SectionCard(
                title: L10n.tr("Review"),
                subtitle: L10n.tr("Make sure the record is clear enough to retrieve quickly later.")
            ) {
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 12) {
                        ValueBadge(title: L10n.tr("Object"), value: name.isEmpty ? L10n.tr("Unnamed") : name)
                        ValueBadge(title: L10n.tr("Category"), value: L10n.categoryName(category))
                    }

                    HStack(spacing: 12) {
                        ValueBadge(title: L10n.tr("Evidence"), value: L10n.format("%lld photos", Int64(valuationPhotoData().count)))
                        ValueBadge(title: L10n.tr("Documents"), value: "\(attachedDocuments.count + (existingItem?.documents.count ?? 0))")
                    }

                    ValueBadge(title: L10n.tr("Estimated value"), value: reviewValuationText, tone: valuationAmount == nil ? .warning : .neutral)
                    StatusBadge(title: L10n.tr("Stored securely"), systemImage: "lock.shield", tone: .neutral)
                }
            }

        }
    }

    private var primaryActionTitle: String {
        if currentStep == .review {
            return isEditing ? L10n.tr("common.save") : L10n.tr("common.add")
        }
        return L10n.tr("Continue")
    }

    private var primaryActionDisabled: Bool {
        switch currentStep {
        case .evidence:
            return false
        case .details:
            return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .review:
            return name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || isSaving
        }
    }

    private var reviewValuationText: String {
        if let valuationAmount {
            return CurrencyFormatter.format(valuationAmount, code: currency, symbol: selectedCurrency?.symbol)
        }
        return L10n.tr("Pending")
    }

    private func advanceStep() {
        guard let next = AddFlowStep(rawValue: currentStep.rawValue + 1) else { return }
        currentStep = next
    }

    private func retreatStep() {
        guard let previous = AddFlowStep(rawValue: currentStep.rawValue - 1) else { return }
        currentStep = previous
    }

    private func labeledField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(BrandTheme.textSecondary)
            content()
        }
    }

    private var selectedCategoryTitle: String {
        config.category(named: category).map {
            L10n.categoryName($0.name, fallback: $0.displayName)
        } ?? L10n.categoryName(category)
    }

    private var selectedCategorySubtitle: String? {
        guard let selected = config.category(named: category) else { return nil }
        guard let group = config.groupedCategories.first(where: {
            $0.parent.name == selected.name || $0.children.contains(selected)
        }) else {
            return nil
        }

        guard group.parent.name != selected.name else { return L10n.tr("Main category") }
        return L10n.categoryName(group.parent.name, fallback: group.parent.displayName)
    }

    private var selectedCategoryIcon: String {
        config.category(named: category)?.icon ?? "archivebox"
    }

    private func saveItem() async {
        isSaving = true
        saveError = nil
        let purchase = Double(purchasePrice) ?? 0
        let valuation = valuationAmount ?? existingItem?.valuationAmount ?? 0

        do {
            if let existing = existingItem {
                // MARK: Update existing item
                let payload = ItemPayload(
                    id: existing.id,
                    userId: existing.userId,
                    inventoryId: existing.inventoryId,
                    name: name,
                    category: category,
                    currency: currency,
                    purchasePrice: purchase,
                    estimatedValue: valuation,
                    aiEstimate: valuation > 0 ? valuation : existing.aiEstimate,
                    yearPurchased: YearFormatter.year(from: purchaseDate),
                    serialNumber: serialNumber,
                    notes: notes,
                    createdAt: existing.createdAt
                )
                _ = try await SupabaseDataService.updateItem(id: existing.id, payload)

                // Update local
                existing.name = name
                existing.category = category
                existing.currency = currency
                existing.purchasePrice = purchase
                existing.estimatedValue = valuation
                existing.aiEstimate = valuation > 0 ? valuation : existing.aiEstimate
                existing.purchaseDate = purchaseDate
                existing.serialNumber = serialNumber
                existing.notes = notes

                // Upload new photos
                let uploadedPhotos = try await uploadPhotos(for: existing.id, inventoryId: existing.inventoryId)
                for uploadedPhoto in uploadedPhotos {
                    let photo = ItemPhoto(
                        id: uploadedPhoto.id,
                        imageData: uploadedPhoto.data,
                        storagePath: uploadedPhoto.storagePath
                    )
                    photo.item = existing
                    modelContext.insert(photo)
                    existing.photos.append(photo)
                }

                // Upload new documents
                let uploadedDocuments = try await uploadDocuments(for: existing.id, inventoryId: existing.inventoryId)
                for uploadedDocument in uploadedDocuments {
                    let document = ItemDocument(
                        id: uploadedDocument.id,
                        filename: uploadedDocument.filename,
                        fileData: uploadedDocument.data,
                        storagePath: uploadedDocument.storagePath
                    )
                    document.item = existing
                    modelContext.insert(document)
                    existing.documents.append(document)
                }
            } else {
                // MARK: Create new item
                let itemId = UUID()
                let now = Date()
                let inventoryId = try await resolvedInventoryId()
                let payload = ItemPayload(
                    id: itemId,
                    userId: auth.userId,
                    inventoryId: inventoryId,
                    name: name,
                    category: category,
                    currency: currency,
                    purchasePrice: purchase,
                    estimatedValue: valuation,
                    aiEstimate: valuation > 0 ? valuation : nil,
                    yearPurchased: YearFormatter.year(from: purchaseDate),
                    serialNumber: serialNumber,
                    notes: notes,
                    createdAt: now
                )
                print("[AddItemView] Inserting item to Supabase...")
                _ = try await SupabaseDataService.insertItem(payload)
                print("[AddItemView] Item inserted successfully.")

                let item = Item(
                    id: itemId,
                    userId: auth.userId,
                    inventoryId: inventoryId,
                    name: name,
                    category: category,
                    currency: currency,
                    purchasePrice: purchase,
                    estimatedValue: valuation,
                    aiEstimate: valuation > 0 ? valuation : nil,
                    purchaseDate: purchaseDate,
                    serialNumber: serialNumber,
                    notes: notes,
                    createdAt: now
                )
                modelContext.insert(item)

                // Upload photos
                let uploadedPhotos = try await uploadPhotos(for: itemId, inventoryId: inventoryId)
                for uploadedPhoto in uploadedPhotos {
                    let photo = ItemPhoto(
                        id: uploadedPhoto.id,
                        imageData: uploadedPhoto.data,
                        storagePath: uploadedPhoto.storagePath
                    )
                    photo.item = item
                    modelContext.insert(photo)
                    item.photos.append(photo)
                }

                // Upload documents
                let uploadedDocuments = try await uploadDocuments(for: itemId, inventoryId: inventoryId)
                for uploadedDocument in uploadedDocuments {
                    let document = ItemDocument(
                        id: uploadedDocument.id,
                        filename: uploadedDocument.filename,
                        fileData: uploadedDocument.data,
                        storagePath: uploadedDocument.storagePath
                    )
                    document.item = item
                    modelContext.insert(document)
                    item.documents.append(document)
                }
            }

            isSaving = false
            dismiss()
        } catch {
            print("[AddItemView] Save failed: \(error)")
            saveError = error.localizedDescription
            isSaving = false
        }
    }

    private func resolvedInventoryId() async throws -> String {
        if let existingItem {
            return existingItem.inventoryId
        }

        if let currentInventoryId = auth.currentUserProfile?.inventoryId, !currentInventoryId.isEmpty {
            return currentInventoryId
        }

        if let profile = try await SupabaseDataService.fetchUserProfile(userId: auth.userId),
           let inventoryId = profile.inventoryId,
           !inventoryId.isEmpty {
            auth.currentUserProfile = profile
            auth.currentInventoryId = inventoryId
            return inventoryId
        }

        return auth.effectiveInventoryId
    }

    private func scheduleValuationRefresh() {
        valuationTask?.cancel()
        valuationTask = Task {
            try? await Task.sleep(for: .milliseconds(350))
            guard !Task.isCancelled else { return }
            await refreshValuationPreview()
        }
    }

    @MainActor
    private func refreshValuationPreview() async {
        let photoData = valuationPhotoData()
        guard !photoData.isEmpty else {
            isRequestingValuation = false
            valuationError = nil
            valuationAmount = existingItem?.valuationAmount
            return
        }

        isRequestingValuation = true
        valuationError = nil

        do {
            let valuation = try await ValuationService.valuate(
                input: ValuationService.Input(
                    name: name,
                    category: category,
                    currency: currency.isEmpty ? config.defaultCurrencyCode : currency,
                    countryCode: Locale.autoupdatingCurrent.region?.identifier ?? "US",
                    purchasePrice: Double(purchasePrice) ?? 0,
                    purchaseDate: purchaseDate,
                    serialNumber: serialNumber,
                    notes: notes,
                    photoCount: photoData.count,
                    documentCount: attachedDocuments.count + (existingItem?.documents.count ?? 0),
                    photoData: photoData
                )
            )
            guard !Task.isCancelled else { return }
            valuationAmount = valuation.amount
            isRequestingValuation = false
        } catch {
            guard !Task.isCancelled else { return }
            valuationError = error.localizedDescription
            isRequestingValuation = false
        }
    }

    private func valuationPhotoData() -> [Data] {
        let existingPhotos = existingItem?.photos.map(\.imageData) ?? []
        let newPhotos = capturedImages.compactMap { image in
            ImageCompressor.compress(image)
        }
        return existingPhotos + newPhotos
    }

    private func uploadPhotos(for itemId: UUID, inventoryId: String) async throws -> [(id: UUID, data: Data, storagePath: String)] {
        return try await withThrowingTaskGroup(of: (Int, UUID, Data, String)?.self) { group in
            for (index, image) in capturedImages.enumerated() {
                group.addTask {
                    guard let data = ImageCompressor.compress(image) else { return nil }

                    let photoId = UUID()
                    let storagePath = try await SupabaseDataService.uploadFile(
                        inventoryId: inventoryId,
                        itemId: itemId,
                        fileId: photoId,
                        filename: "photo.jpg",
                        data: data,
                        contentType: "image/jpeg"
                    )
                    let payload = PhotoPayload(
                        id: photoId,
                        itemId: itemId,
                        storagePath: storagePath,
                        capturedAt: Date()
                    )
                    _ = try await SupabaseDataService.insertPhotoRecord(payload)
                    return (index, photoId, data, storagePath)
                }
            }

            var uploadedPhotos: [(Int, UUID, Data, String)] = []
            for try await result in group {
                if let result {
                    uploadedPhotos.append(result)
                }
            }

            return uploadedPhotos
                .sorted { $0.0 < $1.0 }
                .map { ($0.1, $0.2, $0.3) }
        }
    }

    private func uploadDocuments(for itemId: UUID, inventoryId: String) async throws -> [(id: UUID, filename: String, data: Data, storagePath: String)] {
        return try await withThrowingTaskGroup(of: (Int, UUID, String, Data, String).self) { group in
            for (index, document) in attachedDocuments.enumerated() {
                group.addTask {
                    let documentId = UUID()
                    let storagePath = try await SupabaseDataService.uploadFile(
                        inventoryId: inventoryId,
                        itemId: itemId,
                        fileId: documentId,
                        filename: document.filename,
                        data: document.data,
                        contentType: "application/octet-stream"
                    )
                    let payload = DocPayload(
                        id: documentId,
                        itemId: itemId,
                        filename: document.filename,
                        storagePath: storagePath,
                        fileSize: document.data.count,
                        addedAt: Date()
                    )
                    _ = try await SupabaseDataService.insertDocumentRecord(payload)
                    return (index, documentId, document.filename, document.data, storagePath)
                }
            }

            var uploadedDocuments: [(Int, UUID, String, Data, String)] = []
            for try await result in group {
                uploadedDocuments.append(result)
            }

            return uploadedDocuments
                .sorted { $0.0 < $1.0 }
                .map { ($0.1, $0.2, $0.3, $0.4) }
        }
    }
}

struct DocumentPickerView: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.pdf, .data])
        picker.delegate = context.coordinator
        picker.allowsMultipleSelection = false
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onPick: onPick) }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        let onPick: (URL) -> Void
        init(onPick: @escaping (URL) -> Void) { self.onPick = onPick }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            guard let url = urls.first else { return }
            _ = url.startAccessingSecurityScopedResource()
            onPick(url)
            url.stopAccessingSecurityScopedResource()
        }
    }
}

private struct CategorySelectionView: View {
    let groups: [AppConfigStore.CategoryGroup]
    @Binding var selectedCategory: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(groups) { group in
                    Section {
                        categoryRow(
                            category: group.parent,
                            subtitle: group.children.isEmpty ? nil : L10n.tr("Main category")
                        )

                        ForEach(group.children) { child in
                            categoryRow(
                                category: child,
                                subtitle: L10n.categoryName(group.parent.name, fallback: group.parent.displayName),
                                indented: true
                            )
                        }
                    } header: {
                        if !group.children.isEmpty {
                            Text(L10n.categoryName(group.parent.name, fallback: group.parent.displayName))
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(BrandTheme.backgroundGradient)
            .navigationTitle(L10n.tr("Select category"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.done")) { dismiss() }
                }
            }
        }
        .brandBackground()
    }

    private func categoryRow(
        category: RemoteCategory,
        subtitle: String?,
        indented: Bool = false
    ) -> some View {
        Button {
            selectedCategory = category.name
            dismiss()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: category.icon ?? "archivebox")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(BrandTheme.accentBright)
                    .frame(width: 22)

                VStack(alignment: .leading, spacing: 3) {
                    Text(L10n.categoryName(category.name, fallback: category.displayName))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(BrandTheme.textPrimary)

                    if let subtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(BrandTheme.textSecondary)
                    }
                }

                Spacer()

                if selectedCategory == category.name {
                    Image(systemName: "checkmark")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(BrandTheme.accentCool)
                }
            }
            .padding(.leading, indented ? 18 : 0)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.clear)
    }
}
