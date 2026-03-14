import SwiftUI

// Root view — delegates to auth gate in VaultDocApp.
struct ContentView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        if auth.isAuthenticated {
            VaultListView(userId: auth.userId)
        } else {
            AuthView()
        }
    }
}
