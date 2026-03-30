import SwiftUI
import SwiftData
import QuickLook

struct ItemDetailView: View {
    @Bindable var item: Item
    @Environment(\.modelContext) private var modelContext
    @Environment(AppConfigStore.self) private var config
    @Environment(AuthService.self) private var auth
    @Environment(LanguageSettings.self) private var language
    @State private var viewModel = ItemDetailViewModel()
    @State private var showEdit = false
    @State private var showCamera = false
    @State private var selectedPhotoIndex = 0
    @State private var photoUploadError: String?
    @State private var previewDocument: PreviewDocument?

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                photoCarousel
                    .frame(height: item.photos.isEmpty ? 200 : 280)

                VStack(spacing: 16) {
                    valueCard
                    infoGrid
                    photoStrip
                    documentsSection
                }
                .padding()
            }
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.large)
        .brandBackground()
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(L10n.tr("common.edit")) { showEdit = true }
            }
        }
        .sheet(isPresented: $showEdit) {
            AddItemView(existingItem: item)
        }
        .sheet(isPresented: $viewModel.showShareSheet) {
            if let data = viewModel.pdfData {
                ShareSheet(items: [data])
            }
        }
        .sheet(item: $previewDocument) { document in
            DocumentPreviewSheet(document: document)
        }
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { imageData in
                Task {
                    do {
                        let photoId = UUID()
                        let uploadData = ImageCompressor.downsampledImage(data: imageData, maxDimension: 2_048)?
                            .jpegData(compressionQuality: 0.8) ?? imageData
                        let storagePath = try await SupabaseDataService.uploadFile(
                            inventoryId: item.inventoryId, itemId: item.id, fileId: photoId,
                            filename: "photo.jpg", data: uploadData, contentType: "image/jpeg"
                        )
                        let payload = PhotoPayload(id: photoId, itemId: item.id, storagePath: storagePath, capturedAt: Date())
                        _ = try await SupabaseDataService.insertPhotoRecord(payload)

                        let photo = ItemPhoto(id: photoId, imageData: uploadData, storagePath: storagePath)
                        photo.item = item
                        modelContext.insert(photo)
                        item.photos.append(photo)
                        viewModel.requestAIEstimate(for: item)
                    } catch {
                        photoUploadError = error.localizedDescription
                    }
                }
            }
        }
        .alert(L10n.tr("item_detail.estimate_error"), isPresented: .constant(viewModel.estimateError != nil)) {
            Button(L10n.tr("common.ok")) { viewModel.estimateError = nil }
        } message: {
            Text(viewModel.estimateError ?? "")
        }
        .alert(L10n.tr("item_detail.upload_error"), isPresented: .constant(photoUploadError != nil)) {
            Button(L10n.tr("common.ok")) { photoUploadError = nil }
        } message: {
            Text(photoUploadError ?? "")
        }
        .task(id: item.photos.count) {
            guard item.aiEstimate == nil, !viewModel.isRequestingEstimate else { return }
            viewModel.requestAIEstimate(for: item)
        }
    }

    // MARK: - Photo Carousel

    private var photoCarousel: some View {
        Group {
            if item.photos.isEmpty {
                ZStack {
                    BrandTheme.accentBright.opacity(0.10)
                        .overlay(BrandTheme.surface)
                    VStack(spacing: 8) {
                        Image(systemName: item.categoryIcon)
                            .font(.system(size: 64))
                            .foregroundStyle(BrandTheme.accentGradient)
                        Text(L10n.tr("item_detail.no_photos_yet"))
                            .font(.caption)
                            .foregroundStyle(BrandTheme.textSecondary)
                    }
                }
            } else {
                TabView(selection: $selectedPhotoIndex) {
                    ForEach(Array(item.photos.enumerated()), id: \.offset) { idx, photo in
                        CachedDataImage(data: photo.imageData, cacheKey: photo.id.uuidString, maxDimension: 1_024)
                            .tag(idx)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .always))
            }
        }
        .clipped()
    }

    // MARK: - Value Card

    private var valueCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("VALUATION")
                    .font(.caption2).bold()
                    .foregroundStyle(.secondary)
                if viewModel.isRequestingEstimate && item.valuationAmount == 0 {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Analyzing photos")
                            .font(.subheadline)
                            .foregroundStyle(BrandTheme.textSecondary)
                    }
                } else if item.valuationAmount > 0 {
                    Text(CurrencyFormatter.format(item.valuationAmount, for: item, config: config))
                        .font(.title2).bold()
                        .foregroundStyle(BrandTheme.accentBright)
                } else {
                    Text("Add photos to calculate")
                        .font(.subheadline)
                        .foregroundStyle(BrandTheme.textSecondary)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                guard !viewModel.isRequestingEstimate else { return }
                viewModel.requestAIEstimate(for: item)
            }
            Spacer()
            Divider().frame(height: 40)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(L10n.tr("item.field.purchase_price").uppercased())
                    .font(.caption2).bold()
                    .foregroundStyle(.secondary)
                Text(CurrencyFormatter.format(item.purchasePrice, for: item, config: config))
                    .font(.title2).bold()
                    .foregroundStyle(BrandTheme.accentGradient)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(BrandTheme.surface)
                .stroke(BrandTheme.border, lineWidth: 1)
        )
    }

    // MARK: - Info Grid

    private var infoGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            InfoCell(label: L10n.tr("item.field.category"), value: item.categoryDisplayName, icon: item.categoryIcon)
            InfoCell(label: L10n.tr("item.field.year_purchased"), value: YearFormatter.display(date: item.purchaseDate), icon: "calendar")
            InfoCell(label: L10n.tr("item.field.purchase_price"), value: CurrencyFormatter.format(item.purchasePrice, for: item, config: config), icon: "banknote")
            InfoCell(label: L10n.tr("item.field.serial_number"),
                     value: item.serialNumber.isEmpty ? L10n.placeholderDash : item.serialNumber,
                     icon: "number")
        }
    }

    // MARK: - Photo Strip

    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(L10n.tr("item_detail.photos"))
                    .font(.headline)
                Spacer()
                Button {
                    showCamera = true
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.teal)
                        .foregroundStyle(BrandTheme.accentBright)
                }
            }
            if item.photos.isEmpty {
                Text(L10n.tr("item_detail.no_photos_attached"))
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(item.photos.enumerated()), id: \.offset) { idx, photo in
                            CachedDataImage(data: photo.imageData, cacheKey: photo.id.uuidString, maxDimension: 72)
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .onTapGesture {
                                    selectedPhotoIndex = idx
                                }
                        }
                        Button {
                            showCamera = true
                        } label: {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(BrandTheme.surface)
                                .frame(width: 72, height: 72)
                                .overlay {
                                    Image(systemName: "plus")
                                        .foregroundStyle(BrandTheme.accentBright)
                                        .font(.title2)
                                }
                        }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(BrandTheme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(BrandTheme.border, lineWidth: 1))
    }

    // MARK: - Documents

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(L10n.tr("item_detail.documents"))
                .font(.headline)
            if item.documents.isEmpty {
                Text(L10n.tr("item_detail.no_documents_attached"))
                    .font(.caption)
                    .foregroundStyle(BrandTheme.textSecondary)
            } else {
                ForEach(item.documents) { doc in
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(BrandTheme.accentBright)
                        VStack(alignment: .leading) {
                            Button {
                                previewDocument = PreviewDocument.make(from: doc)
                            } label: {
                                Text(doc.filename)
                                    .font(.subheadline)
                                    .lineLimit(1)
                                    .foregroundStyle(BrandTheme.accentBright)
                            }
                            Text(doc.formattedSize)
                                .font(.caption)
                                .foregroundStyle(BrandTheme.textSecondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
            Button {
                viewModel.generatePDF(for: item)
            } label: {
                Label(L10n.tr("item_detail.export_pdf"), systemImage: "arrow.up.doc")
                    .font(.subheadline)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(BrandTheme.accentGradient)
                    .foregroundStyle(BrandTheme.actionForeground)
                    .clipShape(Capsule())
            }
            .padding(.top, 4)
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(BrandTheme.surface))
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(BrandTheme.border, lineWidth: 1))
    }
}

struct InfoCell: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(BrandTheme.accentBright)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(BrandTheme.textSecondary)
                Text(value)
                    .font(.subheadline)
                    .lineLimit(1)
                    .foregroundStyle(BrandTheme.textPrimary)
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(BrandTheme.elevatedSurface))
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct DocumentPreviewSheet: UIViewControllerRepresentable {
    let document: PreviewDocument

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: QLPreviewController, context: Context) {
        context.coordinator.document = document
        uiViewController.reloadData()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(document: document)
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var document: PreviewDocument

        init(document: PreviewDocument) {
            self.document = document
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            document.url as NSURL
        }
    }
}

struct PreviewDocument: Identifiable {
    let id: UUID
    let url: URL

    static func make(from document: ItemDocument) -> PreviewDocument? {
        let filename = document.filename.isEmpty ? "Document" : document.filename
        let sanitizedName = filename.replacingOccurrences(of: "/", with: "-")
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(document.id.uuidString)
            .appendingPathExtension((sanitizedName as NSString).pathExtension)

        do {
            try document.fileData.write(to: url, options: .atomic)
            return PreviewDocument(id: document.id, url: url)
        } catch {
            return nil
        }
    }
}

struct CachedDataImage: View {
    let data: Data
    let cacheKey: String
    let maxDimension: CGFloat

    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(BrandTheme.surface)
                    .task(id: cacheKey) {
                        image = await DataImageCache.shared.image(
                            for: cacheKey,
                            data: data,
                            maxDimension: maxDimension
                        )
                    }
            }
        }
    }
}

@MainActor
final class DataImageCache {
    static let shared = DataImageCache()

    private let cache = NSCache<NSString, UIImage>()

    private init() {}

    func image(for key: String, data: Data, maxDimension: CGFloat) async -> UIImage? {
        let cacheKey = "\(key)-\(Int(maxDimension))" as NSString
        if let cached = cache.object(forKey: cacheKey) {
            return cached
        }

        let image = await Task.detached(priority: .userInitiated) {
            ImageCompressor.downsampledImage(data: data, maxDimension: maxDimension)
        }.value

        if let image {
            cache.setObject(image, forKey: cacheKey)
        }
        return image
    }
}
