import SwiftUI
import SwiftData

struct ItemDetailView: View {
    @Bindable var item: Item
    @State private var viewModel = ItemDetailViewModel()
    @State private var showEdit = false
    @State private var showCamera = false
    @State private var selectedPhotoIndex = 0

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
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Edit") { showEdit = true }
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
                let photo = ItemPhoto(imageData: imageData)
                photo.item = item
                item.photos.append(photo)
            }
        }
        .alert("Estimate Error", isPresented: .constant(viewModel.estimateError != nil)) {
            Button("OK") { viewModel.estimateError = nil }
        } message: {
            Text(viewModel.estimateError ?? "")
        }
    }

    // MARK: - Photo Carousel

    private var photoCarousel: some View {
        Group {
            if item.photos.isEmpty {
                ZStack {
                    Color.teal.opacity(0.1)
                    VStack(spacing: 8) {
                        Image(systemName: item.categoryIcon)
                            .font(.system(size: 64))
                            .foregroundStyle(.teal.opacity(0.5))
                        Text("No photos yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                Text("DECLARED VALUE")
                    .font(.caption2).bold()
                    .foregroundStyle(.secondary)
                Text(CurrencyFormatter.format(item.estimatedValue))
                    .font(.title2).bold()
                    .foregroundStyle(Color(red: 0.031, green: 0.314, blue: 0.255))
            }
            Spacer()
            Divider().frame(height: 40)
            Spacer()
            VStack(alignment: .trailing, spacing: 4) {
                Text("AI ESTIMATE")
                    .font(.caption2).bold()
                    .foregroundStyle(.secondary)
                if viewModel.isRequestingEstimate {
                    ProgressView()
                } else if let ai = item.aiEstimate {
                    Text(CurrencyFormatter.format(ai))
                        .font(.title2).bold()
                        .foregroundStyle(.teal)
                } else {
                    Button {
                        viewModel.requestAIEstimate(for: item)
                    } label: {
                        Text("Get Estimate")
                            .font(.subheadline)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.teal.opacity(0.15))
                            .foregroundStyle(.teal)
                            .clipShape(Capsule())
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.teal.opacity(0.08))
                .stroke(Color.teal.opacity(0.3), lineWidth: 1)
        )
    }

    // MARK: - Info Grid

    private var infoGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            InfoCell(label: "Category", value: item.categoryDisplayName, icon: item.categoryIcon)
            InfoCell(label: "Year", value: String(item.yearPurchased), icon: "calendar")
            InfoCell(label: "Purchase Price", value: CurrencyFormatter.format(item.purchasePrice), icon: "eurosign")
            InfoCell(label: "Serial Number",
                     value: item.serialNumber.isEmpty ? "—" : item.serialNumber,
                     icon: "number")
        }
    }

    // MARK: - Photo Strip

    private var photoStrip: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Photos")
                    .font(.headline)
                Spacer()
                Button {
                    showCamera = true
                } label: {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(.teal)
                }
            }
            if item.photos.isEmpty {
                Text("No photos attached")
                    .font(.caption)
                    .foregroundStyle(.secondary)
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
                                .fill(Color.teal.opacity(0.1))
                                .frame(width: 72, height: 72)
                                .overlay {
                                    Image(systemName: "plus")
                                        .foregroundStyle(.teal)
                                        .font(.title2)
                                }
                        }
                    }
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }

    // MARK: - Documents

    private var documentsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Documents")
                    .font(.headline)
                Spacer()
                Button {
                    viewModel.generatePDF(for: item)
                } label: {
                    Label("Export PDF", systemImage: "arrow.up.doc")
                        .font(.subheadline)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.teal)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            if item.documents.isEmpty {
                Text("No documents attached")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                ForEach(item.documents) { doc in
                    HStack {
                        Image(systemName: "doc.fill")
                            .foregroundStyle(.teal)
                        VStack(alignment: .leading) {
                            Text(doc.filename)
                                .font(.subheadline)
                                .lineLimit(1)
                            Text(doc.formattedSize)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.vertical, 4)
                    Divider()
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 16).fill(Color(.secondarySystemBackground)))
    }
}

struct InfoCell: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.teal)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color(.secondarySystemBackground)))
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
