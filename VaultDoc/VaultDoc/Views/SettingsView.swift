import SwiftUI

struct SettingsView: View {
    let items: [Item]
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigStore.self) private var config
    @Environment(AuthService.self) private var auth

    @State private var apiKey = ""
    @State private var isAPIKeyVisible = false
    @State private var showShareSheet = false
    @State private var pdfData: Data?
    @State private var defaultCurrencyCode = ""

    var body: some View {
        NavigationStack {
            Form {
                // MARK: Account
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.title)
                            .foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Signed in as")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Text(auth.userEmail)
                                .font(.subheadline)
                        }
                    }
                    Button(role: .destructive) {
                        Task {
                            await auth.signOut()
                        }
                    } label: {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } header: {
                    Text("Account")
                }

                // MARK: Anthropic
                Section {
                    HStack {
                        if isAPIKeyVisible {
                            TextField("sk-ant-...", text: $apiKey)
                                .autocorrectionDisabled()
                                .textInputAutocapitalization(.never)
                        } else {
                            SecureField("sk-ant-...", text: $apiKey)
                        }
                        Button {
                            isAPIKeyVisible.toggle()
                        } label: {
                            Image(systemName: isAPIKeyVisible ? "eye.slash" : "eye")
                                .foregroundStyle(.secondary)
                        }
                    }
                    Button("Save API Key") {
                        KeychainHelper.shared.save(apiKey, forKey: KeychainHelper.anthropicAPIKey)
                    }
                    .disabled(apiKey.isEmpty)
                } header: {
                    Text("Anthropic API Key")
                } footer: {
                    Text("Required for AI value estimates. Stored securely in the device keychain.")
                }

                // MARK: Current config
                Section("Active Categories (\(config.categories.count))") {
                    ForEach(config.categories) { cat in
                        HStack {
                            Image(systemName: cat.icon ?? "archivebox")
                                .foregroundStyle(.teal)
                                .frame(width: 24)
                            Text(cat.displayName)
                            Spacer()
                            Text(cat.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Active Currencies (\(config.currencies.count))") {
                    Picker("Default Currency", selection: $defaultCurrencyCode) {
                        ForEach(config.currencies) { cur in
                            Text("\(cur.symbol)  \(cur.code) — \(cur.name)").tag(cur.code)
                        }
                    }

                    ForEach(config.currencies) { cur in
                        HStack {
                            Text(cur.symbol)
                                .font(.headline)
                                .foregroundStyle(.teal)
                                .frame(width: 32)
                            Text(cur.name)
                            Spacer()
                            Text(cur.code)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: Export
                Section("Export") {
                    Button {
                        exportAll()
                    } label: {
                        Label("Export All Items as PDF", systemImage: "arrow.up.doc.fill")
                    }
                    .disabled(items.isEmpty)
                }

                // MARK: About
                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Build")
                        Spacer()
                        Text("1").foregroundStyle(.secondary)
                    }
                    NavigationLink("Privacy Policy") {
                        PrivacyPolicyView()
                    }
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let data = pdfData {
                    ShareSheet(items: [data])
                }
            }
            .onAppear {
                apiKey = KeychainHelper.shared.load(forKey: KeychainHelper.anthropicAPIKey) ?? ""
                defaultCurrencyCode = config.defaultCurrencyCode
            }
            .onChange(of: defaultCurrencyCode) { _, newCode in
                guard !newCode.isEmpty, !auth.userId.isEmpty else { return }
                config.setDefaultCurrency(code: newCode)
                Task {
                    do {
                        try await config.saveDefaultCurrency(userId: auth.userId)
                    } catch {
                        config.lastError = error.localizedDescription
                    }
                }
            }
        }
    }

    private func exportAll() {
        pdfData = PDFGenerator.generateAll(items: items)
        showShareSheet = true
    }
}

struct PrivacyPolicyView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Privacy Policy")
                    .font(.largeTitle).bold()
                Group {
                    Text("Data Storage")
                        .font(.headline)
                    Text("VaultDoc stores all your data locally on your device using SwiftData. No data is sent to external servers except when you request an AI estimate, which sends item details to the Anthropic API.")

                    Text("Camera & Photos")
                        .font(.headline)
                    Text("VaultDoc accesses your camera and photo library only to capture and attach photos to your items. Photos are stored locally on your device.")

                    Text("API Key")
                        .font(.headline)
                    Text("Your Anthropic API key is stored securely in the device Keychain and is never transmitted or stored outside your device, except to authenticate with the Anthropic API.")

                    Text("Contact")
                        .font(.headline)
                    Text("For privacy inquiries, please contact us through the App Store listing.")
                }
                .foregroundStyle(.secondary)
            }
            .padding()
        }
        .navigationTitle("Privacy Policy")
        .navigationBarTitleDisplayMode(.inline)
    }
}
