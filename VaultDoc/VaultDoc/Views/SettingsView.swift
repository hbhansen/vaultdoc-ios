import SwiftUI

struct SettingsView: View {
    let items: [Item]
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigStore.self) private var config
    @Environment(AuthService.self) private var auth
    @Environment(LanguageSettings.self) private var language

    @State private var showShareSheet = false
    @State private var pdfData: Data?
    @State private var defaultCurrencyCode = ""
    @State private var isSavingCurrency = false
    @State private var settingsError: String?

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
                            Text(L10n.tr("settings.signed_in_as"))
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
                        Label(L10n.tr("settings.sign_out"), systemImage: "rectangle.portrait.and.arrow.right")
                    }
                } header: {
                    Text(L10n.tr("settings.account"))
                }

                // MARK: Current config
                Section(L10n.format("settings.active_categories_count", Int64(config.categories.count))) {
                    ForEach(config.categories) { cat in
                        HStack {
                            Image(systemName: cat.icon ?? "archivebox")
                                .foregroundStyle(.teal)
                                .frame(width: 24)
                            Text(L10n.categoryName(cat.name, fallback: cat.displayName))
                            Spacer()
                            Text(cat.name)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section(L10n.format("settings.active_currencies_count", Int64(config.currencies.count))) {
                    Picker(L10n.tr("settings.default_currency"), selection: $defaultCurrencyCode) {
                        ForEach(config.currencies) { cur in
                            Text("\(cur.symbol)  \(cur.code) — \(L10n.currencyName(code: cur.code, fallback: cur.name))").tag(cur.code)
                        }
                    }
                    .disabled(isSavingCurrency)

                    ForEach(config.currencies) { cur in
                        HStack {
                            Text(cur.symbol)
                                .font(.headline)
                                .foregroundStyle(.teal)
                                .frame(width: 32)
                            Text(L10n.currencyName(code: cur.code, fallback: cur.name))
                            Spacer()
                            Text(cur.code)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if let settingsError {
                    Section {
                        Text(settingsError)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                }

                Section(L10n.tr("settings.language")) {
                    Picker(L10n.tr("settings.app_language"), selection: Bindable(language).selectedLanguage) {
                        ForEach(LanguageSettings.AppLanguage.allCases) { appLanguage in
                            Text(appLanguage.localizedName)
                                .tag(appLanguage)
                        }
                    }
                }

                // MARK: Export
                Section(L10n.tr("settings.export")) {
                    Button {
                        exportAll()
                    } label: {
                        Label(L10n.tr("settings.export_all_items_pdf"), systemImage: "arrow.up.doc.fill")
                    }
                    .disabled(items.isEmpty)
                }

                // MARK: About
                Section(L10n.tr("settings.about")) {
                    HStack {
                        Text(L10n.tr("settings.version"))
                        Spacer()
                        Text("1.0.0").foregroundStyle(.secondary)
                    }
                    HStack {
                        Text(L10n.tr("settings.build"))
                        Spacer()
                        Text("1").foregroundStyle(.secondary)
                    }
                    NavigationLink(L10n.tr("settings.privacy_policy")) {
                        PrivacyPolicyView()
                    }
                }
            }
            .navigationTitle(L10n.tr("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .scrollContentBackground(.hidden)
            .background(BrandTheme.backgroundGradient)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(L10n.tr("common.done")) { dismiss() }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let data = pdfData {
                    ShareSheet(items: [data])
                }
            }
            .onAppear {
                defaultCurrencyCode = config.defaultCurrencyCode
            }
            .onChange(of: defaultCurrencyCode) { _, newCode in
                guard !newCode.isEmpty, !auth.userId.isEmpty else { return }
                Task {
                    isSavingCurrency = true
                    settingsError = nil
                    do {
                        try await config.applyProjectCurrency(
                            code: newCode,
                            to: items,
                            userId: auth.userId
                        )
                    } catch {
                        settingsError = error.localizedDescription
                        defaultCurrencyCode = config.defaultCurrencyCode
                    }
                    isSavingCurrency = false
                }
            }
        }
        .brandBackground()
    }

    private func exportAll() {
        pdfData = PDFGenerator.generateAll(items: items)
        showShareSheet = true
    }
}

struct PrivacyPolicyView: View {
    @Environment(LanguageSettings.self) private var language

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text(L10n.tr("settings.privacy_policy"))
                    .font(.system(.largeTitle, design: .serif, weight: .bold))
                    .foregroundStyle(BrandTheme.textPrimary)
                Group {
                    Text(L10n.tr("privacy.data_storage"))
                        .font(.headline)
                    Text(L10n.tr("privacy.data_storage_body"))

                    Text(L10n.tr("privacy.camera_photos"))
                        .font(.headline)
                    Text(L10n.tr("privacy.camera_photos_body"))

                    Text(L10n.tr("privacy.ai_estimates"))
                        .font(.headline)
                    Text(L10n.tr("privacy.ai_estimates_body"))

                    Text(L10n.tr("privacy.contact"))
                        .font(.headline)
                    Text(L10n.tr("privacy.contact_body"))
                }
                .foregroundStyle(BrandTheme.textSecondary)
            }
            .padding()
        }
        .navigationTitle(L10n.tr("settings.privacy_policy"))
        .navigationBarTitleDisplayMode(.inline)
        .brandBackground()
    }
}
