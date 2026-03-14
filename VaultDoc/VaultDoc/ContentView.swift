import SwiftUI

// Root view — delegates to VaultListView which owns the NavigationStack.
struct ContentView: View {
    var body: some View {
        VaultListView()
    }
}
