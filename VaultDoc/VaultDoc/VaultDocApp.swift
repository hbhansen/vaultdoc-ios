import SwiftUI
import SwiftData

@main
struct VaultDocApp: App {
    @State private var languageSettings = LanguageSettings.shared

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
            Group {
                if AuthService.shared.isAuthenticated {
                    VaultListView(userId: AuthService.shared.userId)
                } else {
                    AuthView()
                }
            }
            .id(languageSettings.selectedLanguage)
            .environment(AppConfigStore.shared)
            .environment(AuthService.shared)
            .environment(languageSettings)
            .environment(\.locale, languageSettings.locale)
            .tint(BrandTheme.accent)
            .task {
                await AuthService.shared.restoreSession()
                await AppConfigStore.shared.refresh(
                    supabaseURL: Config.Supabase.url,
                    supabaseKey: Config.Supabase.anonKey
                )
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
