import SwiftUI
import SwiftData
import PhotosUI
import UniformTypeIdentifiers

struct AddItemView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var existingItem: Item? = nil

    @State private var name = ""
    @State private var category = "other"
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

    var body: some View {
        NavigationStack {
            Form {
                Section("Item Details") {
                    TextField("Name", text: $name)
                    Picker("Category", selection: $category) {
                        ForEach(Item.categories, id: \.self) { cat in
                            Text(cat.prefix(1).uppercased() + cat.dropFirst()).tag(cat)
                        }
                    }
                    HStack {
                        Text("€")
                        TextField("Purchase Price", text: $purchasePrice)
                            .keyboardType(.decimalPad)
                    }
                    HStack {
                        Text("€")
                        TextField("Declared Value", text: $estimatedValue)
                            .keyboardType(.decimalPad)
                    }
                    Stepper("Year: \(yearPurchased)", value: $yearPurchased,
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
                        saveItem()
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
                    purchasePrice = item.purchasePrice > 0 ? String(item.purchasePrice) : ""
                    estimatedValue = item.estimatedValue > 0 ? String(item.estimatedValue) : ""
                    yearPurchased = item.yearPurchased
                    serialNumber = item.serialNumber
                    notes = item.notes
                }
            }
        }
    }

    private func saveItem() {
        isSaving = true
        let purchase = Double(purchasePrice) ?? 0
        let declared = Double(estimatedValue) ?? 0

        let item: Item
        if let existing = existingItem {
            existing.name = name
            existing.category = category
            existing.purchasePrice = purchase
            existing.estimatedValue = declared
            existing.yearPurchased = yearPurchased
            existing.serialNumber = serialNumber
            existing.notes = notes
            item = existing
        } else {
            item = Item(
                name: name,
                category: category,
                purchasePrice: purchase,
                estimatedValue: declared,
                yearPurchased: yearPurchased,
                serialNumber: serialNumber,
                notes: notes
            )
            modelContext.insert(item)
        }

        for image in capturedImages {
            if let data = ImageCompressor.compress(image) {
                let photo = ItemPhoto(imageData: data)
                photo.item = item
                modelContext.insert(photo)
                item.photos.append(photo)
            }
        }

        for doc in attachedDocuments {
            let document = ItemDocument(filename: doc.filename, fileData: doc.data)
            document.item = item
            modelContext.insert(document)
            item.documents.append(document)
        }

        Task {
            if !name.isEmpty && purchase > 0 {
                if let value = try? await AnthropicService.estimateValue(
                    name: item.name,
                    category: item.category,
                    purchasePrice: item.purchasePrice,
                    year: item.yearPurchased
                ) {
                    item.aiEstimate = value
                }
            }
        }

        isSaving = false
        dismiss()
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
