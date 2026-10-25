import SwiftUI

struct AccountSection: View {
    @EnvironmentObject private var auth: AuthManager
    @State private var folderStatus: FolderStatus = .idle

    enum FolderStatus: Equatable {
        case idle
        case checking
        case ready(name: String)
        case failed(String)
    }

    var body: some View {
        Group {
            switch auth.state {
            case .unconfigured:
                Label {
                    Text("This build has no Google client ID. Set the GOOGLE_CLIENT_ID_PREFIX repository variable and rebuild.")
                } icon: {
                    Image(systemName: "exclamationmark.triangle")
                        .foregroundStyle(.orange)
                }
            case .restoring:
                HStack {
                    ProgressView()
                    Text("Checking sign-in…")
                }
            case .signedOut:
                Button {
                    Task { await auth.signIn() }
                } label: {
                    Label("Sign in with Google", systemImage: "person.crop.circle.badge.plus")
                }
            case let .signedIn(email):
                LabeledContent("Account", value: email)
                folderRow
                Button("Sign out", role: .destructive) {
                    auth.signOut()
                }
            }

            if let message = auth.errorMessage {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }
        }
        .task(id: auth.state) {
            await checkFolder()
        }
    }

    @ViewBuilder
    private var folderRow: some View {
        switch folderStatus {
        case .idle, .checking:
            HStack {
                ProgressView()
                Text("Connecting to Drive…")
            }
        case let .ready(name):
            Label("Drive folder “\(name)” is ready", systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case let .failed(message):
            VStack(alignment: .leading, spacing: 8) {
                Label(message, systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.red)
                Button("Try again") {
                    Task { await checkFolder() }
                }
            }
        }
    }

    private func checkFolder() async {
        guard case .signedIn = auth.state else {
            folderStatus = .idle
            return
        }
        folderStatus = .checking
        let client = DriveClient { [auth] in try await auth.accessToken() }
        do {
            let folder = try await client.ensureRootFolder()
            folderStatus = .ready(name: folder.name)
        } catch {
            folderStatus = .failed(error.localizedDescription)
        }
    }
}
