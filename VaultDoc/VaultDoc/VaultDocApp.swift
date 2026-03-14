import SwiftUI
import SwiftData

@main
struct VaultDocApp: App {
    @AppStorage("supabaseURL") private var supabaseURL = ""
    @AppStorage("supabaseKey") private var supabaseKey = ""

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
                        supabaseURL: supabaseURL,
                        supabaseKey: supabaseKey
                    )
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
