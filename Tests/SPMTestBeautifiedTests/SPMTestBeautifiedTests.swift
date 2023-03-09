import FooLib
import XCTest

final class SPMTestBeautifiedTests: XCTestCase {
  func testFail() {
    XCTFail()
  }

  func testFooWelcome() {
    let foo = Foo()

    XCTAssertEqual(foo.message, "Hello world")
  }

  func testSuccess() {
    XCTAssertEqual(true, true)
  }

  func testBar() {
    XCTFail("This fail should not be reported when filtered")
  }
  func testExtended() {
    XCTFail("This fail should not be reported when filtered")
  }
}
