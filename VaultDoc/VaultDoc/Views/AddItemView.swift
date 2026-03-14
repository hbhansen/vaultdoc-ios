import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigStore.self) private var config
    @Environment(AuthService.self) private var auth
    @Environment(LanguageSettings.self) private var language

    var existingItem: Item? = nil

    @State private var name = ""
    @State private var category = "other"
    @State private var currency = ""
    @State private var purchasePrice = ""
    @State private var estimatedValue = ""
    @State private var yearPurchased = YearFormatter.currentYear
    @State private var serialNumber = ""
    @State private var notes = ""

    @State private var photoItems: [PhotosPickerItem] = []
    @State private var capturedImages: [UIImage] = []
    @State private var showCamera = false
    @State private var showDocumentPicker = false
    @State private var attachedDocuments: [(filename: String, data: Data)] = []

    @State private var isSaving = false
    @State private var saveError: String?

    var isEditing: Bool { existingItem != nil }
    var title: String { isEditing ? L10n.tr("add_item.edit_title") : L10n.tr("add_item.add_title") }

    var selectedCurrency: RemoteCurrency? {
        config.currency(code: currency)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section(L10n.tr("add_item.section.details")) {
                    TextField(L10n.tr("item.field.name"), text: $name)

                    Picker(L10n.tr("item.field.category"), selection: $category) {
                        ForEach(config.categories) { cat in
                            HStack {
                                Image(systemName: cat.icon ?? "archivebox")
                                Text(L10n.categoryName(cat.name, fallback: cat.displayName))
                            }
                            .tag(cat.name)
                        }
                    }

                    LabeledContent(L10n.tr("item.field.currency")) {
                        Text(
                            "\(selectedCurrency?.symbol ?? config.currency(code: config.defaultCurrencyCode)?.symbol ?? "€")  \(currency)"
                        )
                        .foregroundStyle(.secondary)
                    }

                    HStack {
                        Text(selectedCurrency?.symbol ?? "€")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        TextField(L10n.tr("item.field.purchase_price"), text: $purchasePrice)
                            .keyboardType(.decimalPad)
                    }

                    HStack {
                        Text(selectedCurrency?.symbol ?? "€")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        TextField(L10n.tr("item.field.declared_value"), text: $estimatedValue)
                            .keyboardType(.decimalPad)
                    }

                    Stepper(
                        L10n.format("item.field.year_format", Int64(yearPurchased)),
                        value: $yearPurchased,
                        in: 1900...YearFormatter.currentYear
                    )
                    TextField(L10n.tr("item.field.serial_number"), text: $serialNumber)
                    TextField(L10n.tr("item.field.notes"), text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section(L10n.tr("item_detail.photos")) {
                    HStack {
                        Button {
                            showCamera = true
                        } label: {
                            Label(L10n.tr("add_item.camera"), systemImage: "camera")
                        }
                        Spacer()
                        PhotosPicker(selection: $photoItems, maxSelectionCount: 10,
                                     matching: .images) {
                            Label(L10n.tr("add_item.library"), systemImage: "photo.on.rectangle")
                        }
                    }
                    if !capturedImages.isEmpty {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack {
                                ForEach(Array(capturedImages.enumerated()), id: \.offset) { idx, img in
                                    Image(uiImage: img)
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 80, height: 80)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                        .overlay(alignment: .topTrailing) {
                                            Button {
                                                capturedImages.remove(at: idx)
                                            } label: {
                                                Image(systemName: "xmark.circle.fill")
                                                    .foregroundStyle(.white)
                                                    .background(Color.black.opacity(0.5), in: Circle())
                                            }
                                            .padding(4)
                                        }
                                }
                            }
                        }
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
                    }
                }

                Section(L10n.tr("item_detail.documents")) {
                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label(L10n.tr("add_item.attach_document"), systemImage: "doc.badge.plus")
                    }
                    ForEach(attachedDocuments, id: \.filename) { doc in
                        HStack {
                            Image(systemName: "doc.fill")
                                .foregroundStyle(.teal)
                            VStack(alignment: .leading) {
                                Text(doc.filename)
                                    .font(.subheadline)
                                Text(ByteCountFormatter.string(fromByteCount: Int64(doc.data.count),
                                                               countStyle: .file))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        attachedDocuments.remove(atOffsets: offsets)
                    }
                }

                if let error = saveError {
                    Section {
                        Text(error)
                            .foregroundStyle(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(BrandTheme.backgroundGradient)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(L10n.tr("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? L10n.tr("common.save") : L10n.tr("common.add")) {
                        Task { await saveItem() }
                    }
                    .disabled(name.isEmpty || isSaving)
                }
            }
            .fullScreenCover(isPresented: $showCamera) {
                CameraView { imageData in
                    if let img = UIImage(data: imageData) {
                        capturedImages.append(img)
                    }
                }
            }
            .sheet(isPresented: $showDocumentPicker) {
                DocumentPickerView { url in
                    if let data = try? Data(contentsOf: url) {
                        attachedDocuments.append((filename: url.lastPathComponent, data: data))
                    }
                }
            }
            .onAppear {
                if let item = existingItem {
                    name = item.name
                    category = item.category
                    currency = config.defaultCurrencyCode
                    purchasePrice = item.purchasePrice > 0 ? String(item.purchasePrice) : ""
                    estimatedValue = item.estimatedValue > 0 ? String(item.estimatedValue) : ""
                    yearPurchased = item.yearPurchased
                    serialNumber = item.serialNumber
                    notes = item.notes
                } else {
                    currency = config.defaultCurrencyCode
                }
            }
            .onChange(of: config.defaultCurrencyCode) { _, newCode in
                guard !newCode.isEmpty else { return }
                currency = newCode
            }
        }
        .brandBackground()
    }

    private func saveItem() async {
        isSaving = true
        saveError = nil
        let purchase = Double(purchasePrice) ?? 0
        let declared = Double(estimatedValue) ?? 0

        do {
            if let existing = existingItem {
                // MARK: Update existing item
                let payload = ItemPayload(
                    id: existing.id,
                    userId: auth.userId,
                    name: name,
                    category: category,
                    currency: currency,
                    purchasePrice: purchase,
                    estimatedValue: declared,
                    aiEstimate: existing.aiEstimate,
                    yearPurchased: yearPurchased,
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
                existing.estimatedValue = declared
                existing.yearPurchased = yearPurchased
                existing.serialNumber = serialNumber
                existing.notes = notes

                // Upload new photos
                let uploadedPhotos = try await uploadPhotos(for: existing.id)
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
                let uploadedDocuments = try await uploadDocuments(for: existing.id)
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
                let payload = ItemPayload(
                    id: itemId,
                    userId: auth.userId,
                    name: name,
                    category: category,
                    currency: currency,
                    purchasePrice: purchase,
                    estimatedValue: declared,
                    aiEstimate: nil,
                    yearPurchased: yearPurchased,
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
                    name: name,
                    category: category,
                    currency: currency,
                    purchasePrice: purchase,
                    estimatedValue: declared,
                    yearPurchased: yearPurchased,
                    serialNumber: serialNumber,
                    notes: notes,
                    createdAt: now
                )
                modelContext.insert(item)

                // Upload photos
                let uploadedPhotos = try await uploadPhotos(for: itemId)
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
                let uploadedDocuments = try await uploadDocuments(for: itemId)
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

                // Async AI estimate
                Task {
                    if !name.isEmpty && purchase > 0 {
                        if let value = try? await AnthropicService.estimateValue(
                            name: item.name,
                            category: item.category,
                            purchasePrice: item.purchasePrice,
                            year: item.yearPurchased
                        ) {
                            item.aiEstimate = value
                            // Persist AI estimate to Supabase
                            var updated = payload
                            updated.aiEstimate = value
                            _ = try? await SupabaseDataService.updateItem(id: itemId, updated)
                        }
                    }
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

    private func uploadPhotos(for itemId: UUID) async throws -> [(id: UUID, data: Data, storagePath: String)] {
        try await withThrowingTaskGroup(of: (Int, UUID, Data, String)?.self) { group in
            for (index, image) in capturedImages.enumerated() {
                group.addTask {
                    guard let data = ImageCompressor.compress(image) else { return nil }

                    let photoId = UUID()
                    let storagePath = try await SupabaseDataService.uploadFile(
                        userId: auth.userId,
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

    private func uploadDocuments(for itemId: UUID) async throws -> [(id: UUID, filename: String, data: Data, storagePath: String)] {
        try await withThrowingTaskGroup(of: (Int, UUID, String, Data, String).self) { group in
            for (index, document) in attachedDocuments.enumerated() {
                group.addTask {
                    let documentId = UUID()
                    let storagePath = try await SupabaseDataService.uploadFile(
                        userId: auth.userId,
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
