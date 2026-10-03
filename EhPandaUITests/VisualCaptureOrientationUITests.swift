import XCTest

final class VisualCaptureOrientationUITests: XCTestCase {
    @MainActor
    func testRotateToPortrait() {
        XCUIDevice.shared.orientation = .portrait
        XCTAssertEqual(XCUIDevice.shared.orientation, .portrait)
    }

    @MainActor
    func testRotateToLandscape() {
        XCUIDevice.shared.orientation = .landscapeLeft
        XCTAssertEqual(XCUIDevice.shared.orientation, .landscapeLeft)
    }
}
