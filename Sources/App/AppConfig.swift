import Foundation

/// Build-time configuration read from Info.plist.
struct AppConfig {
    static let clientIDSuffix = ".apps.googleusercontent.com"
    static let current = AppConfig(infoDictionary: Bundle.main.infoDictionary ?? [:])

    /// The Google OAuth iOS client ID, or nil when the build was made without one.
    let googleClientID: String?

    init(infoDictionary: [String: Any]) {
        let raw = (infoDictionary["GIDClientID"] as? String)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        googleClientID = Self.isValidClientID(raw) ? raw : nil
    }

    static func isValidClientID(_ clientID: String) -> Bool {
        clientID.hasSuffix(clientIDSuffix)
            && clientID.count > clientIDSuffix.count
            && !clientID.hasPrefix(".")
            && !clientID.contains("$(")
    }
}
