import SwiftUI
import SwiftData

@main
struct VaultDocApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Item.self,
            ItemPhoto.self,
            ItemDocument.self
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            VaultListView()
                .environment(AppConfigStore.shared)
                .task {
                    await AppConfigStore.shared.refresh(
                        supabaseURL: Config.Supabase.url,
                        supabaseKey: Config.Supabase.anonKey
                    )
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
