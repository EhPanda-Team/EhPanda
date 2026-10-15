import CoreGraphics
import XCTest

@MainActor
extension XCUIApplication {
    func returnFromGalleryDetail(file: StaticString = #filePath, line: UInt = #line) {
        let detail = descendants(matching: .any)["detail_view"].firstMatch
        XCTAssertTrue(detail.waitForExistence(timeout: 10), file: file, line: line)
        let close = descendants(matching: .any)["Close"].firstMatch
        let back = descendants(matching: .any)["BackButton"].firstMatch
        if close.exists {
            close.tapWhenHittable("Close gallery detail", file: file, line: line)
        } else if back.exists {
            back.tapWhenHittable("Return from gallery detail", file: file, line: line)
        } else {
            // A native floating sheet dismisses through its surrounding dimming surface.
            let window = windows.firstMatch
            let panel = detail.frame
            let bounds = window.frame
            let origin = window.coordinate(withNormalizedOffset: .zero)
            if panel.minX > bounds.minX {
                origin.withOffset(CGVector(dx: (panel.minX - bounds.minX) / 2, dy: bounds.height / 2)).tap()
            } else if panel.minY > bounds.minY {
                origin.withOffset(CGVector(dx: bounds.width / 2, dy: (panel.minY - bounds.minY) / 2)).tap()
            } else {
                XCTFail("Gallery detail exposes neither a return control nor a floating-sheet margin.",
                        file: file, line: line)
                return
            }
        }
        XCTAssertTrue(detail.waitForNonExistence(timeout: 10), "Detail must actually close.", file: file, line: line)
    }
}
