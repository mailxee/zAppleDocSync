import XCTest
@testable import zAppleDocSync

final class DriveClientTests: XCTestCase {
    private var client: DriveClient!

    override func setUp() {
        super.setUp()
        MockURLProtocol.reset()
        client = DriveClient(session: MockURLProtocol.makeSession()) { "test-token" }
    }

    override func tearDown() {
        MockURLProtocol.reset()
        super.tearDown()
    }

    func testEnsureRootFolderReturnsExistingFolder() async throws {
        MockURLProtocol.handler = { _ in
            (200, Data(#"{"files":[{"id":"abc","name":"zAppleDocSync","mimeType":"application/vnd.google-apps.folder"}]}"#.utf8))
        }

        let folder = try await client.ensureRootFolder()

        XCTAssertEqual(folder.id, "abc")
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
        let request = try XCTUnwrap(MockURLProtocol.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")
        let query = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "q" }?.value)
        XCTAssertTrue(query.contains("name = 'zAppleDocSync'"))
        XCTAssertTrue(query.contains("'root' in parents"))
        XCTAssertTrue(query.contains("trashed = false"))
    }

    func testEnsureRootFolderCreatesFolderWhenMissing() async throws {
        MockURLProtocol.handler = { request in
            if request.httpMethod == "POST" {
                return (200, Data(#"{"id":"new","name":"zAppleDocSync","mimeType":"application/vnd.google-apps.folder"}"#.utf8))
            }
            return (200, Data(#"{"files":[]}"#.utf8))
        }

        let folder = try await client.ensureRootFolder()

        XCTAssertEqual(folder.id, "new")
        XCTAssertEqual(MockURLProtocol.requests.map(\.httpMethod), ["GET", "POST"])
        let body = try XCTUnwrap(MockURLProtocol.requests.last?.httpBody)
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: Any])
        XCTAssertEqual(json["name"] as? String, "zAppleDocSync")
        XCTAssertEqual(json["mimeType"] as? String, DriveClient.folderMimeType)
        XCTAssertEqual(json["parents"] as? [String], ["root"])
    }

    func testHTTPErrorSurfacesGoogleMessage() async {
        MockURLProtocol.handler = { _ in
            (403, Data(#"{"error":{"code":403,"message":"Insufficient permissions"}}"#.utf8))
        }

        do {
            _ = try await client.ensureRootFolder()
            XCTFail("Expected an error")
        } catch {
            XCTAssertEqual(error as? DriveError, .http(status: 403, message: "Insufficient permissions"))
        }
    }

    func testQueryValuesWithSpecialCharactersSurviveEncoding() async throws {
        MockURLProtocol.handler = { _ in (200, Data(#"{"files":[]}"#.utf8)) }

        _ = try await client.findFolder(named: "Tom's A&B = C+D", parentID: "root")

        let request = try XCTUnwrap(MockURLProtocol.requests.first)
        let query = try XCTUnwrap(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
            .queryItems?.first { $0.name == "q" }?.value)
        XCTAssertTrue(query.contains(#"name = 'Tom\'s A&B = C+D'"#), query)
    }

    func testEscapeHandlesQuotesAndBackslashes() {
        XCTAssertEqual(DriveClient.escape(#"a'b\c"#), #"a\'b\\c"#)
    }
}
