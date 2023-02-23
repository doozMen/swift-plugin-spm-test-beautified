import XCTest

final class SPMTestBeautifiedTests: XCTestCase {
    func testFail() {
        XCTFail()
    }

    func testSuccess() {
      XCTAssertEqual(true, true)
    }
}
