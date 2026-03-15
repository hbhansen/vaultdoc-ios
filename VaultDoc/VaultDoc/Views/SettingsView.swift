import SwiftUI

struct SettingsView: View {
    let items: [Item]
    var onInventoryChanged: () async -> Void = {}
    @Environment(\.dismiss) private var dismiss
    @Environment(AppConfigStore.self) private var config
    @Environment(AuthService.self) private var auth
    @Environment(LanguageSettings.self) private var language

    @State private var showShareSheet = false
    @State private var pdfData: Data?
    @State private var defaultCurrencyCode = ""
    @State private var isSavingCurrency = false
    @State private var settingsError: String?
    @State private var inviteEmail = ""
    @State private var isSendingInvite = false
    @State private var isApplyingInvite = false
    @State private var sharingStatus: String?

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

                Section {
                    if auth.inventoryMembers.isEmpty {
                        Text("Your inventory is currently private.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(auth.inventoryMembers) { member in
                            HStack {
                                Image(systemName: member.id == auth.userId ? "person.crop.circle.badge.checkmark" : "person.2.fill")
                                    .foregroundStyle(.teal)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(member.email ?? member.id)
                                    if member.id == auth.userId {
                                        Text("You")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }

                    TextField("Family member email", text: $inviteEmail)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)
                        .autocorrectionDisabled()

                    Button {
                        Task {
                            await sendInventoryInvite()
                        }
                    } label: {
                        Label("Send family invite", systemImage: "person.badge.plus")
                    }
                    .disabled(isSendingInvite || inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    if !auth.pendingInventoryInvites.isEmpty {
                        ForEach(auth.pendingInventoryInvites) { invite in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(invite.invitedByEmail)
                                    .font(.subheadline.weight(.semibold))
                                Text("Invited you to join a shared family inventory.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                Button {
                                    Task {
                                        await accept(invite: invite)
                                    }
                                } label: {
                                    Label("Accept invite", systemImage: "checkmark.circle.fill")
                                }
                                .disabled(isApplyingInvite)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                } header: {
                    Text("Shared Inventory")
                } footer: {
                    Text("Invited family members can add items to the same inventory after they accept the invite.")
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

                if let sharingStatus {
                    Section {
                        Text(sharingStatus)
                            .font(.caption)
                            .foregroundStyle(.secondary)
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
                Task {
                    await auth.refreshUserContext()
                }
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

    private func sendInventoryInvite() async {
        let normalizedEmail = inviteEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedEmail.isEmpty else { return }
        guard normalizedEmail != auth.userEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() else {
            settingsError = "Use another family member's email."
            return
        }

        isSendingInvite = true
        settingsError = nil
        sharingStatus = nil

        do {
            let profile: UserProfilePayload?
            if let currentProfile = auth.currentUserProfile {
                profile = currentProfile
            } else {
                profile = try await SupabaseDataService.fetchUserProfile(userId: auth.userId)
            }
            let inventoryId = profile?.inventoryId ?? auth.effectiveInventoryId
            let existingProfile = try await SupabaseDataService.fetchUserProfile(email: normalizedEmail)

            if existingProfile?.inventoryId == inventoryId {
                sharingStatus = "\(normalizedEmail) is already in this inventory."
                isSendingInvite = false
                return
            }

            let pendingInvites = try await SupabaseDataService.fetchPendingInventoryInvites(email: normalizedEmail)
            if pendingInvites.contains(where: { $0.inventoryId == inventoryId }) {
                sharingStatus = "An invite is already pending for \(normalizedEmail)."
                isSendingInvite = false
                return
            }

            let invite = InventoryInvitePayload(
                id: UUID(),
                inventoryId: inventoryId,
                invitedEmail: normalizedEmail,
                invitedByUserId: auth.userId,
                invitedByEmail: auth.userEmail,
                status: "pending",
                createdAt: Date()
            )
            _ = try await SupabaseDataService.createInventoryInvite(invite)
            inviteEmail = ""
            sharingStatus = "Invite sent to \(normalizedEmail)."
            await auth.refreshUserContext()
        } catch {
            settingsError = error.localizedDescription
        }

        isSendingInvite = false
    }

    private func accept(invite: InventoryInvitePayload) async {
        isApplyingInvite = true
        settingsError = nil
        sharingStatus = nil

        do {
            let profile: UserProfilePayload?
            if let currentProfile = auth.currentUserProfile {
                profile = currentProfile
            } else {
                profile = try await SupabaseDataService.fetchUserProfile(userId: auth.userId)
            }
            try await migrateOwnedItems(to: invite.inventoryId)
            let payload = UserProfilePayload(
                id: auth.userId,
                email: auth.userEmail.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                defaultCurrency: profile?.defaultCurrency,
                inventoryId: invite.inventoryId
            )
            _ = try await SupabaseDataService.upsertUserProfile(payload)

            var acceptedInvite = invite
            acceptedInvite.status = "accepted"
            _ = try await SupabaseDataService.updateInventoryInvite(acceptedInvite)

            await auth.refreshUserContext()
            await onInventoryChanged()
            sharingStatus = "You are now sharing the family inventory."
        } catch {
            settingsError = error.localizedDescription
        }

        isApplyingInvite = false
    }

    private func migrateOwnedItems(to inventoryId: String) async throws {
        let ownedItems = try await SupabaseDataService.fetchItems(userId: auth.userId)
        let itemsToMove = ownedItems.filter { $0.inventoryId != inventoryId }

        guard !itemsToMove.isEmpty else { return }

        try await withThrowingTaskGroup(of: UUID.self) { group in
            for item in itemsToMove {
                group.addTask {
                    var updatedItem = item
                    updatedItem.inventoryId = inventoryId
                    _ = try await SupabaseDataService.updateItem(id: item.id, updatedItem)
                    return item.id
                }
            }

            var movedIds = Set<UUID>()
            for try await movedId in group {
                movedIds.insert(movedId)
            }

            for item in items where movedIds.contains(item.id) {
                item.inventoryId = inventoryId
            }
        }
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
