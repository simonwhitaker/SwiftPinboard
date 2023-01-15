import XCTest
@testable import SwiftPinboard

@available(macOS 12.0, *)
final class SwiftPinboardTests: XCTestCase {
    func testGetURLWithAuthToken() throws {
        let client = PinboardClient(authToken: "foo")
        let urlString = client.getURLString(path: "/bar", queryArgs: ["baz":"wibble"])
        XCTAssertEqual(urlString, "https://api.pinboard.in/v1/bar?auth_token=foo&baz=wibble&format=json")
    }

    func testGetURLWithoutAuthToken() throws {
        let client = PinboardClient()
        let urlString = client.getURLString(path: "/bar", queryArgs: ["baz":"wibble"])
        XCTAssertEqual(urlString, "https://api.pinboard.in/v1/bar?baz=wibble&format=json")
    }

    func testGetURLWithEncodedQueryArgs() throws {
        let client = PinboardClient()
        let urlString = client.getURLString(path: "/bar", queryArgs: ["baz":"Wibble Wobble"])
        XCTAssertEqual(urlString, "https://api.pinboard.in/v1/bar?baz=Wibble%20Wobble&format=json")
    }

    func testAddBookmarkWithoutAuthFails() async throws {
        let client = PinboardClient()
        do {
            try await client.addBookmark(url: "https://netcetera.org", title: "Netcetera", description: nil)
            XCTFail("addBookmark succeeded unexpectedly")
        } catch PinboardClientError.AuthenticationError {
            return
        } catch {
            XCTFail("Request failed with unexpected error: \(error)")
        }
    }
}
