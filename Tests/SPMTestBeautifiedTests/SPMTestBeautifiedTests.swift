import XCTest
import FooLib

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

  func testSomething_skipped() {
    XCTFail("This fail should not be reported when filtered")
  }
}
