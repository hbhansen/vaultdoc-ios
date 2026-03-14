import SwiftUI
import SwiftData

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
        .fullScreenCover(isPresented: $showCamera) {
            CameraView { imageData in
                Task {
                    do {
                        let photoId = UUID()
                        let storagePath = try await SupabaseDataService.uploadFile(
                            userId: auth.userId, itemId: item.id, fileId: photoId,
                            filename: "photo.jpg", data: imageData, contentType: "image/jpeg"
                        )
                        let payload = PhotoPayload(id: photoId, itemId: item.id, storagePath: storagePath, capturedAt: Date())
                        _ = try await SupabaseDataService.insertPhotoRecord(payload)

                        let photo = ItemPhoto(id: photoId, imageData: imageData, storagePath: storagePath)
                        photo.item = item
                        modelContext.insert(photo)
                        item.photos.append(photo)
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
    }

    // MARK: - Photo Carousel

    private var photoCarousel: some View {
        Group {
            if item.photos.isEmpty {
                ZStack {
                    Color.teal.opacity(0.1)
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
                        if let ui = UIImage(data: photo.imageData) {
                            Image(uiImage: ui)
                                .resizable()
                                .scaledToFill()
                                .tag(idx)
                        }
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
                Text(L10n.tr("item_detail.declared_value_uppercase"))
                    .font(.caption2).bold()
                    .foregroundStyle(.secondary)
                Text(CurrencyFormatter.format(item.estimatedValue, for: item, config: config))
                    .font(.title2).bold()
                    .foregroundStyle(BrandTheme.accentBright)
            }
            Spacer()
            Divider().frame(height: 40)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text(L10n.tr("item_detail.ai_estimate_uppercase"))
                    .font(.caption2).bold()
                    .foregroundStyle(.secondary)
                if viewModel.isRequestingEstimate {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text(L10n.tr("item_detail.estimate_coming"))
                            .font(.subheadline)
                            .foregroundStyle(BrandTheme.textSecondary)
                    }
                } else if let ai = item.aiEstimate {
                    Text(CurrencyFormatter.format(ai, for: item, config: config))
                        .font(.title2).bold()
                        .foregroundStyle(BrandTheme.accentGradient)
                } else {
                    Button {
                        viewModel.requestAIEstimate(for: item)
                    } label: {
                        Text(L10n.tr("item_detail.get_estimate"))
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(BrandTheme.surface)
                            .foregroundStyle(BrandTheme.accentBright)
                            .clipShape(Capsule())
                    }
                }
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
            InfoCell(label: L10n.tr("item.field.year"), value: String(item.yearPurchased), icon: "calendar")
            InfoCell(label: L10n.tr("item.field.purchase_price"), value: CurrencyFormatter.format(item.purchasePrice, for: item, config: config), icon: "eurosign")
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
                            if let ui = UIImage(data: photo.imageData) {
                                Image(uiImage: ui)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .onTapGesture {
                                        selectedPhotoIndex = idx
                                    }
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
            HStack {
                Text(L10n.tr("item_detail.documents"))
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.generatePDF(for: item)
                } label: {
                    Label(L10n.tr("item_detail.export_pdf"), systemImage: "arrow.up.doc")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(BrandTheme.accentGradient)
                        .foregroundStyle(BrandTheme.backgroundBottom)
                        .clipShape(Capsule())
                }
            }
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
                            Text(doc.filename)
                                .font(.subheadline)
                                .lineLimit(1)
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
