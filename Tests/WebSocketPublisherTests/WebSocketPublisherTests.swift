import XCTest
@testable import WebSocketPublisher

final class WebSocketPublisherTests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(WebSocketPublisher().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
