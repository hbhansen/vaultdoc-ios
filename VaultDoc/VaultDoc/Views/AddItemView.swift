import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigStore.self) private var config
    @Environment(AuthService.self) private var auth

    var existingItem: Item? = nil

    @State private var name = ""
    @State private var category = "other"
    @State private var currency = ""
    @State private var purchasePrice = ""
    @State private var estimatedValue = ""
    @State private var yearPurchased = Calendar.current.component(.year, from: Date())
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
    var title: String { isEditing ? "Edit Item" : "Add Item" }

    var selectedCurrency: RemoteCurrency? {
        config.currency(code: currency)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Name", text: $name)

                    Picker("Category", selection: $category) {
                        ForEach(config.categories) { cat in
                            HStack {
                                Image(systemName: cat.icon ?? "archivebox")
                                Text(cat.displayName)
                            }
                            .tag(cat.name)
                        }
                    }

                    Picker("Currency", selection: $currency) {
                        ForEach(config.currencies) { cur in
                            Text("\(cur.symbol)  \(cur.code) — \(cur.name)").tag(cur.code)
                        }
                    }

                    HStack {
                        Text(selectedCurrency?.symbol ?? "€")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        TextField("Purchase Price", text: $purchasePrice)
                            .keyboardType(.decimalPad)
                    }

                    HStack {
                        Text(selectedCurrency?.symbol ?? "€")
                            .foregroundStyle(.secondary)
                            .frame(width: 24)
                        TextField("Declared Value", text: $estimatedValue)
                            .keyboardType(.decimalPad)
                    }

                    Stepper("Year: \(String(yearPurchased))", value: $yearPurchased,
                            in: 1900...Calendar.current.component(.year, from: Date()))
                    TextField("Serial Number", text: $serialNumber)
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(3, reservesSpace: true)
                }

                Section("Photos") {
                    HStack {
                        Button {
                            showCamera = true
                        } label: {
                            Label("Camera", systemImage: "camera")
                        }
                        Spacer()
                        PhotosPicker(selection: $photoItems, maxSelectionCount: 10,
                                     matching: .images) {
                            Label("Library", systemImage: "photo.on.rectangle")
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

                Section("Documents") {
                    Button {
                        showDocumentPicker = true
                    } label: {
                        Label("Attach Document", systemImage: "doc.badge.plus")
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
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isEditing ? "Save" : "Add") {
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
                    currency = item.currency
                    purchasePrice = item.purchasePrice > 0 ? String(item.purchasePrice) : ""
                    estimatedValue = item.estimatedValue > 0 ? String(item.estimatedValue) : ""
                    yearPurchased = item.yearPurchased
                    serialNumber = item.serialNumber
                    notes = item.notes
                } else {
                    currency = config.defaultCurrencyCode
                }
            }
        }
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
                for image in capturedImages {
                    if let data = ImageCompressor.compress(image) {
                        let photoId = UUID()
                        let storagePath = try await SupabaseDataService.uploadFile(
                            userId: auth.userId, itemId: existing.id, fileId: photoId,
                            filename: "photo.jpg", data: data, contentType: "image/jpeg"
                        )
                        let photoPayload = PhotoPayload(id: photoId, itemId: existing.id, storagePath: storagePath, capturedAt: Date())
                        _ = try await SupabaseDataService.insertPhotoRecord(photoPayload)

                        let photo = ItemPhoto(id: photoId, imageData: data, storagePath: storagePath)
                        photo.item = existing
                        modelContext.insert(photo)
                        existing.photos.append(photo)
                    }
                }

                // Upload new documents
                for doc in attachedDocuments {
                    let docId = UUID()
                    let storagePath = try await SupabaseDataService.uploadFile(
                        userId: auth.userId, itemId: existing.id, fileId: docId,
                        filename: doc.filename, data: doc.data, contentType: "application/octet-stream"
                    )
                    let docPayload = DocPayload(id: docId, itemId: existing.id, filename: doc.filename, storagePath: storagePath, fileSize: doc.data.count, addedAt: Date())
                    _ = try await SupabaseDataService.insertDocumentRecord(docPayload)

                    let document = ItemDocument(id: docId, filename: doc.filename, fileData: doc.data, storagePath: storagePath)
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
                for (index, image) in capturedImages.enumerated() {
                    if let data = ImageCompressor.compress(image) {
                        let photoId = UUID()
                        print("[AddItemView] Uploading photo \(index + 1)/\(capturedImages.count), size: \(data.count) bytes")
                        let storagePath = try await SupabaseDataService.uploadFile(
                            userId: auth.userId, itemId: itemId, fileId: photoId,
                            filename: "photo.jpg", data: data, contentType: "image/jpeg"
                        )
                        print("[AddItemView] Photo uploaded, inserting record...")
                        let photoPayload = PhotoPayload(id: photoId, itemId: itemId, storagePath: storagePath, capturedAt: Date())
                        _ = try await SupabaseDataService.insertPhotoRecord(photoPayload)
                        print("[AddItemView] Photo record inserted.")

                        let photo = ItemPhoto(id: photoId, imageData: data, storagePath: storagePath)
                        photo.item = item
                        modelContext.insert(photo)
                        item.photos.append(photo)
                    } else {
                        print("[AddItemView] Warning: ImageCompressor.compress returned nil for photo \(index + 1)")
                    }
                }

                // Upload documents
                for (index, doc) in attachedDocuments.enumerated() {
                    let docId = UUID()
                    print("[AddItemView] Uploading doc \(index + 1)/\(attachedDocuments.count): \(doc.filename)")
                    let storagePath = try await SupabaseDataService.uploadFile(
                        userId: auth.userId, itemId: itemId, fileId: docId,
                        filename: doc.filename, data: doc.data, contentType: "application/octet-stream"
                    )
                    print("[AddItemView] Doc uploaded, inserting record...")
                    let docPayload = DocPayload(id: docId, itemId: itemId, filename: doc.filename, storagePath: storagePath, fileSize: doc.data.count, addedAt: Date())
                    _ = try await SupabaseDataService.insertDocumentRecord(docPayload)
                    print("[AddItemView] Doc record inserted.")

                    let document = ItemDocument(id: docId, filename: doc.filename, fileData: doc.data, storagePath: storagePath)
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
