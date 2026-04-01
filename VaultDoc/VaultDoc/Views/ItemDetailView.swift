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
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                photoCarousel
                    .frame(height: item.photos.isEmpty ? 180 : 260)
                    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))

                headerSection
                evidenceSection
                metadataSection
                valuationSection
            }
            .padding(20)
            .padding(.bottom, 32)
        }
        .navigationTitle(item.name)
        .navigationBarTitleDisplayMode(.inline)
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

    private var photoCarousel: some View {
        Group {
            if item.photos.isEmpty {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(BrandTheme.surface)
                    .overlay {
                        VStack(spacing: 10) {
                            Image(systemName: item.categoryIcon)
                                .font(.system(size: 42, weight: .semibold))
                                .foregroundStyle(BrandTheme.accentBright)
                            Text(L10n.tr("item_detail.no_photos_yet"))
                                .font(.system(size: 15, weight: .medium))
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
                .tabViewStyle(.page(indexDisplayMode: .automatic))
            }
        }
    }

    private var headerSection: some View {
        SectionCard(
            title: item.name,
            subtitle: L10n.tr("Proof of ownership and recovery-ready records.")
        ) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 12) {
                    ValueBadge(
                        title: L10n.tr("Estimated value"),
                        value: valuationText,
                        tone: item.valuationAmount > 0 ? .neutral : .warning
                    )
                    ValueBadge(
                        title: L10n.tr("Status"),
                        value: item.vaultStatus.title,
                        tone: item.vaultStatus.tone
                    )
                }

                HStack(spacing: 8) {
                    StatusBadge(title: L10n.tr("Encrypted"), systemImage: "lock.shield", tone: .neutral)
                    StatusBadge(
                        title: item.aiEstimate == nil ? L10n.tr("Manual review") : L10n.tr("AI assisted"),
                        systemImage: item.aiEstimate == nil ? "person.crop.square" : "brain",
                        tone: item.aiEstimate == nil ? .warning : .positive
                    )
                }
            }
        }
    }

    private var evidenceSection: some View {
        SectionCard(
            title: L10n.tr("Evidence"),
            subtitle: L10n.tr("Images and documents supporting ownership.")
        ) {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text(L10n.tr("item_detail.photos"))
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(BrandTheme.textPrimary)
                        Spacer()
                        Button(L10n.tr("Add photo")) {
                            showCamera = true
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BrandTheme.accentBright)
                    }

                    if item.photos.isEmpty {
                        Text(L10n.tr("item_detail.no_photos_attached"))
                            .font(.system(size: 15))
                            .foregroundStyle(BrandTheme.textSecondary)
                    } else {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 10) {
                                ForEach(Array(item.photos.enumerated()), id: \.offset) { idx, photo in
                                    CachedDataImage(data: photo.imageData, cacheKey: photo.id.uuidString, maxDimension: 88)
                                        .frame(width: 88, height: 88)
                                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                        .onTapGesture {
                                            selectedPhotoIndex = idx
                                        }
                                }
                            }
                        }
                    }
                }

                Divider()
                    .overlay(BrandTheme.border)

                VStack(alignment: .leading, spacing: 10) {
                    Text(L10n.tr("item_detail.documents"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(BrandTheme.textPrimary)

                    if item.documents.isEmpty {
                        Text(L10n.tr("item_detail.no_documents_attached"))
                            .font(.system(size: 15))
                            .foregroundStyle(BrandTheme.textSecondary)
                    } else {
                        ForEach(item.documents) { doc in
                            Button {
                                previewDocument = PreviewDocument.make(from: doc)
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: "doc.text")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(BrandTheme.accentBright)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(doc.filename)
                                            .font(.system(size: 16, weight: .medium))
                                            .foregroundStyle(BrandTheme.textPrimary)
                                            .lineLimit(1)
                                        Text(doc.formattedSize)
                                            .font(.system(size: 14))
                                            .foregroundStyle(BrandTheme.textSecondary)
                                    }

                                    Spacer()

                                    Image(systemName: "arrow.up.right.square")
                                        .foregroundStyle(BrandTheme.textSecondary)
                                }
                                .padding(.vertical, 8)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }

    private var metadataSection: some View {
        SectionCard(
            title: L10n.tr("Metadata"),
            subtitle: L10n.tr("The details that matter in urgent situations.")
        ) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                InfoCell(label: L10n.tr("item.field.category"), value: item.categoryDisplayName, icon: item.categoryIcon)
                InfoCell(label: L10n.tr("item.field.year_purchased"), value: YearFormatter.display(date: item.purchaseDate), icon: "calendar")
                InfoCell(label: L10n.tr("item.field.purchase_price"), value: CurrencyFormatter.format(item.purchasePrice, for: item, config: config), icon: "banknote")
                InfoCell(
                    label: L10n.tr("item.field.serial_number"),
                    value: item.serialNumber.isEmpty ? L10n.placeholderDash : item.serialNumber,
                    icon: "number"
                )
            }
        }
    }

    private var valuationSection: some View {
        SectionCard(
            title: L10n.tr("Valuation"),
            subtitle: L10n.tr("Conservative estimate based on available evidence.")
        ) {
            VStack(alignment: .leading, spacing: 16) {
                if viewModel.isRequestingEstimate && item.valuationAmount == 0 {
                    HStack(spacing: 10) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L10n.tr("Analyzing evidence"))
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(BrandTheme.textSecondary)
                    }
                } else {
                    Text(valuationText)
                        .font(.system(size: 34, weight: .bold))
                        .foregroundStyle(BrandTheme.textPrimary)
                }

                HStack(spacing: 12) {
                    ValueBadge(title: L10n.tr("Confidence"), value: confidenceTitle, tone: confidenceTone)
                    ValueBadge(title: L10n.tr("Signals"), value: supportingSignalsText)
                }

                Button {
                    guard !viewModel.isRequestingEstimate else { return }
                    viewModel.requestAIEstimate(for: item)
                } label: {
                    Text(item.photos.isEmpty ? L10n.tr("Add evidence to estimate value") : L10n.tr("Refresh estimate"))
                }
                .buttonStyle(PrimaryActionButtonStyle())
                .disabled(item.photos.isEmpty || viewModel.isRequestingEstimate)

                Button {
                    viewModel.generatePDF(for: item)
                } label: {
                    Text(L10n.tr("item_detail.export_pdf"))
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(BrandTheme.accentBright)
                }
            }
        }
    }

    private var valuationText: String {
        if item.valuationAmount > 0 {
            return CurrencyFormatter.format(item.valuationAmount, for: item, config: config)
        }
        return L10n.tr("Pending")
    }

    private var confidenceTitle: String {
        switch item.vaultStatus {
        case .verified:
            return L10n.tr("Higher")
        case .incomplete:
            return L10n.tr("Moderate")
        case .missingEvidence:
            return L10n.tr("Low")
        }
    }

    private var confidenceTone: VaultStatusTone {
        switch item.vaultStatus {
        case .verified:
            return .positive
        case .incomplete:
            return .warning
        case .missingEvidence:
            return .critical
        }
    }

    private var supportingSignalsText: String {
        L10n.format("%lld photos • %lld docs", Int64(item.photos.count), Int64(item.documents.count))
    }
}

struct InfoCell: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(BrandTheme.accentBright)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(BrandTheme.textSecondary)
                Text(value)
                    .font(.system(size: 16, weight: .medium))
                    .lineLimit(2)
                    .foregroundStyle(BrandTheme.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 104, alignment: .topLeading)
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 14).fill(BrandTheme.surfaceElevated))
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
