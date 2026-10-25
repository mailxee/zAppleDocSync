import GoogleSignIn
import UIKit

/// Owns the Google sign-in session and hands out Drive access tokens.
@MainActor
final class AuthManager: ObservableObject {
    enum State: Equatable {
        case unconfigured
        case restoring
        case signedOut
        case signedIn(email: String)
    }

    /// Lets the app see and manage only the files it creates.
    static let driveScope = "https://www.googleapis.com/auth/drive.file"

    @Published private(set) var state: State
    @Published var errorMessage: String?

    init(config: AppConfig = .current) {
        if let clientID = config.googleClientID {
            GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)
            state = .restoring
        } else {
            state = .unconfigured
        }
    }

    func restore() async {
        guard state == .restoring else { return }
        do {
            let user = try await GIDSignIn.sharedInstance.restorePreviousSignIn()
            apply(user)
        } catch {
            state = .signedOut
        }
    }

    func signIn() async {
        guard state != .unconfigured else { return }
        guard let presenter = UIApplication.shared.topViewController else {
            errorMessage = "Could not show the Google sign-in screen."
            return
        }
        errorMessage = nil
        do {
            let result = try await GIDSignIn.sharedInstance.signIn(
                withPresenting: presenter,
                hint: nil,
                additionalScopes: [Self.driveScope]
            )
            apply(result.user)
        } catch GIDSignInError.canceled {
            // User closed the sign-in sheet; nothing to report.
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func signOut() {
        GIDSignIn.sharedInstance.signOut()
        state = .signedOut
    }

    /// A fresh access token for Drive API calls.
    func accessToken() async throws -> String {
        guard let user = GIDSignIn.sharedInstance.currentUser else {
            throw DriveError.notSignedIn
        }
        let refreshed = try await user.refreshTokensIfNeeded()
        return refreshed.accessToken.tokenString
    }

    private func apply(_ user: GIDGoogleUser) {
        guard user.grantedScopes?.contains(Self.driveScope) == true else {
            // Google lets people untick individual permissions on the consent screen.
            GIDSignIn.sharedInstance.signOut()
            state = .signedOut
            errorMessage = "Google Drive access is required. Sign in again and allow access to Drive."
            return
        }
        state = .signedIn(email: user.profile?.email ?? "Google account")
    }
}

extension UIApplication {
    var topViewController: UIViewController? {
        let scenes = connectedScenes.compactMap { $0 as? UIWindowScene }
        let scene = scenes.first { $0.activationState == .foregroundActive } ?? scenes.first
        var top = scene?.keyWindow?.rootViewController
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}
