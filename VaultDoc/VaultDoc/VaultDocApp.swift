import SwiftUI
import SwiftData

@main
struct VaultDocApp: App {
    @State private var configStore = AppConfigStore.shared
    @State private var languageSettings = LanguageSettings.shared
    @State private var showsOpeningSplash = true

    var sharedModelContainer: ModelContainer = {
        let schema = Schema([Item.self, ItemPhoto.self, ItemDocument.self])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // Schema changed without a migration plan (e.g. new field added).
            // Wipe the local store so the app can launch with the updated schema.
            // Safe at this stage — add a SchemaMigrationPlan before shipping to
            // real users with data they must not lose.
            Self.deleteStore()
            do {
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                fatalError("Could not create ModelContainer after store reset: \(error)")
            }
        }
    }()

    var body: some Scene {
        WindowGroup {
            ZStack {
                Group {
                    if AuthService.shared.showsAuthenticatedContent {
                        VaultListView()
                    } else {
                        AuthView()
                    }
                }
                .opacity(showsOpeningSplash ? 0 : 1)

                if showsOpeningSplash {
                    OpeningSplashView()
                        .transition(.opacity)
                        .zIndex(1)
                }
            }
            .id(configStore.brandAppearance)
            .id(languageSettings.selectedLanguage)
            .environment(configStore)
            .environment(AuthService.shared)
            .environment(languageSettings)
            .environment(\.locale, languageSettings.locale)
            .tint(BrandTheme.accent)
            .onOpenURL { url in
                AuthService.shared.recordIncomingURL(url)
                Task {
                    await AuthService.shared.handleIncomingURL(url)
                }
            }
            .task {
                let minimumDisplayTask = Task {
                    try? await Task.sleep(for: .seconds(1.2))
                }
                AuthService.shared.refreshBiometricAvailability()
                await configStore.refresh(
                    supabaseURL: Config.Supabase.url,
                    supabaseKey: Config.Supabase.anonKey
                )
                await configStore.applyPersistedBrandAppearance()
                await minimumDisplayTask.value
                withAnimation(.easeOut(duration: 0.45)) {
                    showsOpeningSplash = false
                }
            }
            .task(id: AuthService.shared.isAuthenticated) {
                guard AuthService.shared.isAuthenticated else { return }
                await AuthService.shared.refreshUserContext()
                await configStore.syncDefaultCurrency(userId: AuthService.shared.userId)
            }
        }
        .modelContainer(sharedModelContainer)
    }

    private static func deleteStore() {
        let appSupport = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first!
        for name in ["default.store", "default.store-shm", "default.store-wal"] {
            try? FileManager.default.removeItem(at: appSupport.appendingPathComponent(name))
        }
    }
}
