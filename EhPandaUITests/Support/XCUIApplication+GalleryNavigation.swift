import CoreGraphics
import XCTest

@MainActor
extension XCUIApplication {
    @discardableResult
    func requireLibraryNavigationTitle(
        _ source: String, file: StaticString = #filePath, line: UInt = #line
    ) -> XCUIElement {
        let sidebar = descendants(matching: .any)["library-categories"].firstMatch
        let menu = descendants(matching: .any)["library-title-menu"].firstMatch
        var readyNavigation: XCUIElement?
        var usesSidebar = false
        // Layout can change while the native bar appears. Choose the presentation anew on every sample, and
        // only retain it once its matching native title and controls are actually ready.
        let ready = NSPredicate { _, _ in
            let hasSidebar = sidebar.exists
            let navigation = self.navigationBars[hasSidebar ? source : "Library"]
            guard navigation.exists, navigation.staticTexts[source].isHittable else { return false }
            if hasSidebar, source == "Downloads" {
                // All Downloads has no selected folder link; its content identifies the selected source.
                guard self.descendants(matching: .any)["downloads-gallery-list"].firstMatch.exists else { return false }
            } else if hasSidebar {
                let categories = sidebar.descendants(matching: .any)
                    .matching(NSPredicate(format: "identifier BEGINSWITH %@", "library-favorites-"))
                guard categories.allElementsBoundByIndex.contains(where: { $0.isSelected && $0.isHittable }) else {
                    return false
                }
            } else {
                guard menu.exists, menu.isHittable else { return false }
            }
            usesSidebar = hasSidebar
            readyNavigation = navigation
            return true
        }
        let wait = XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: nil)], timeout: 15)
        XCTAssertEqual(wait, .completed, "Library's native title and selected source did not become ready.",
                       file: file, line: line)
        let navigation = readyNavigation ?? navigationBars[sidebar.exists ? source : "Library"]
        XCTAssertTrue(navigation.exists, file: file, line: line)
        if !usesSidebar {
            XCTAssertTrue(menu.exists, file: file, line: line)
            XCTAssertTrue(menu.isHittable, file: file, line: line)
        }
        XCTAssertTrue(navigation.staticTexts[source].isHittable, file: file, line: line)
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
