import CoreGraphics
import XCTest

@MainActor
extension XCUIApplication {
    @discardableResult
    func requireLibraryNavigationTitle(
        _ source: String, file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        let hasSidebar = descendants(matching: .any)["library-categories"].firstMatch.exists
        let navigation = navigationBars[hasSidebar ? source : "Library"]
        XCTAssertTrue(navigation.waitForExistence(timeout: 15), file: file, line: line)
        if hasSidebar {
            XCTAssertTrue(navigation.staticTexts[source].isHittable, file: file, line: line)
        } else {
            let menu = descendants(matching: .any)["library-title-menu"].firstMatch
            XCTAssertTrue(menu.waitForExistence(timeout: 5), file: file, line: line)
            XCTAssertTrue(menu.isHittable, file: file, line: line)
            XCTAssertTrue(navigation.staticTexts[source].isHittable, file: file, line: line)
        }
        return navigation
    }

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
