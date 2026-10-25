import Foundation

enum DriveError: LocalizedError, Equatable {
    case notSignedIn
    case http(status: Int, message: String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .notSignedIn:
            return "Not signed in to Google."
        case let .http(status, message):
            return "Google Drive error \(status): \(message)"
        case .invalidResponse:
            return "Google Drive returned an unexpected response."
        }
    }
}

struct DriveFile: Decodable, Equatable {
    let id: String
    let name: String
    let mimeType: String?
}

/// Minimal Google Drive v3 REST client.
final class DriveClient {
    static let folderMimeType = "application/vnd.google-apps.folder"
    static let rootFolderName = "zAppleDocSync"

    private let session: URLSession
    private let tokenProvider: () async throws -> String
    private let baseURL = URL(string: "https://www.googleapis.com/drive/v3")!

    init(session: URLSession = .shared, tokenProvider: @escaping () async throws -> String) {
        self.session = session
        self.tokenProvider = tokenProvider
    }

    /// Finds the app's top-level folder in My Drive, creating it if needed.
    func ensureRootFolder() async throws -> DriveFile {
        if let existing = try await findFolder(named: Self.rootFolderName, parentID: "root") {
            return existing
        }
        return try await createFolder(named: Self.rootFolderName, parentID: "root")
    }

    func findFolder(named name: String, parentID: String) async throws -> DriveFile? {
        let query = [
            "name = '\(Self.escape(name))'",
            "mimeType = '\(Self.folderMimeType)'",
            "'\(Self.escape(parentID))' in parents",
            "trashed = false",
        ].joined(separator: " and ")

        var components = URLComponents(url: baseURL.appendingPathComponent("files"), resolvingAgainstBaseURL: false)!
        components.percentEncodedQuery = Self.encodeQuery([
            ("q", query),
            ("spaces", "drive"),
            ("fields", "files(id,name,mimeType)"),
            ("pageSize", "10"),
        ])
        let request = URLRequest(url: components.url!)

        struct FileList: Decodable { let files: [DriveFile] }
        let list: FileList = try await send(request)
        return list.files.first
    }

    func createFolder(named name: String, parentID: String) async throws -> DriveFile {
        var components = URLComponents(url: baseURL.appendingPathComponent("files"), resolvingAgainstBaseURL: false)!
        components.percentEncodedQuery = Self.encodeQuery([("fields", "id,name,mimeType")])

        var request = URLRequest(url: components.url!)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "name": name,
            "mimeType": Self.folderMimeType,
            "parents": [parentID],
        ])
        return try await send(request)
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        var request = request
        let token = try await tokenProvider()
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw DriveError.invalidResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw DriveError.http(status: http.statusCode, message: Self.errorMessage(from: data))
        }
        do {
            return try JSONDecoder().decode(T.self, from: data)
        } catch {
            throw DriveError.invalidResponse
        }
    }

    /// Escapes a value for use inside single quotes in a Drive query.
    static func escape(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "'", with: "\\'")
    }

    /// Percent-encodes query items strictly, so "&", "=", "+" and "'" in values survive.
    static func encodeQuery(_ items: [(String, String)]) -> String {
        var allowed = CharacterSet.alphanumerics
        allowed.insert(charactersIn: "-._~")
        return items
            .map { key, value in
                let k = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let v = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(k)=\(v)"
            }
            .joined(separator: "&")
    }

    private static func errorMessage(from data: Data) -> String {
        struct Envelope: Decodable {
            struct Body: Decodable { let message: String }
            let error: Body
        }
        if let envelope = try? JSONDecoder().decode(Envelope.self, from: data) {
            return envelope.error.message
        }
        return String(data: data, encoding: .utf8) ?? ""
    }
}
