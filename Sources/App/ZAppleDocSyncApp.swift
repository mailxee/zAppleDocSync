import GoogleSignIn
import SwiftUI

@main
struct ZAppleDocSyncApp: App {
    @StateObject private var auth = AuthManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(auth)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
                .task {
                    await auth.restore()
                }
        }
    }
}
