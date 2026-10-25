import SwiftUI

struct ContentView: View {
    var body: some View {
        NavigationStack {
            List {
                Section("Google Drive") {
                    AccountSection()
                }
                Section("Sync pairs") {
                    Label("Folder and album syncing arrives in the next update.", systemImage: "arrow.triangle.2.circlepath")
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("DocSync")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(AuthManager(config: AppConfig(infoDictionary: [:])))
}
