import XCTest
@testable import Socket

final class Socket_Tests: XCTestCase {
    func testExample() {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct
        // results.
        XCTAssertEqual(sweet_http().text, "Hello, World!")
    }

    static var allTests = [
        ("testExample", testExample),
    ]
}
