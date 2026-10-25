import XCTest
@testable import zAppleDocSync

final class AppConfigTests: XCTestCase {
    func testValidClientID() {
        let config = AppConfig(infoDictionary: ["GIDClientID": "1234-abcd.apps.googleusercontent.com"])
        XCTAssertEqual(config.googleClientID, "1234-abcd.apps.googleusercontent.com")
    }

    func testEmptyPrefixIsUnconfigured() {
        let config = AppConfig(infoDictionary: ["GIDClientID": ".apps.googleusercontent.com"])
        XCTAssertNil(config.googleClientID)
    }

    func testMissingOrUnexpandedValueIsUnconfigured() {
        XCTAssertNil(AppConfig(infoDictionary: [:]).googleClientID)
        XCTAssertNil(AppConfig(infoDictionary: ["GIDClientID": "$(GOOGLE_CLIENT_ID_PREFIX).apps.googleusercontent.com"]).googleClientID)
    }
}
