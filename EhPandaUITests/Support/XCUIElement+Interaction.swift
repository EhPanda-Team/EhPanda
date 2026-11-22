import XCTest

@MainActor
extension XCUIElement {
    /// How long a control has to become hittable. Most of it is XCUITest's own time, not the app's: each check
    /// resolves the element in a fresh snapshot of the app's hierarchy, and under the UITests plan's parallel iPad
    /// clones one resolution can take seconds. The share sheet's Close button, already on screen, took 9.4 s to
    /// resolve once (2026-11-03, five clones), so a 10-second wait could end after a single check.
    static let hittableTimeout: TimeInterval = 30

    /// Waits for a control to accept a tap, including any preceding menu or sheet transition.
    func tapWhenHittable(
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let becameHittable = waitUntilHittable(timeout: Self.hittableTimeout)
        if !becameHittable {
            attachScreenState("\(name) not hittable")
        }
        XCTAssertTrue(becameHittable, "\(name) never became hittable.", file: file, line: line)
        tap()
    }

    /// Opens a gallery entry's Detail with a tap outside its cover, since a tap on the cover reads (D146).
    ///
    /// The bottom centre is the text column of a row, beside or below the cover, and the information under a grid
    /// card's cover, in both layouts and at every text size. A grid card can be taller than the space between the
    /// bars (iPhone landscape shows only its cover), so the list is first dragged until that edge is in view.
    func tapGalleryOutsideCover(
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        revealBottomEdge()
        tapGallery(at: CGVector(dx: 0.5, dy: 1), offset: CGVector(dx: 0, dy: -6), name, file: file, line: line)
    }

    /// Drags the scroll view under this element up, slowly and without momentum, until the element's bottom edge
    /// sits above the tab bar, or the window's bottom when there is none.
    private func revealBottomEdge() {
        let app = XCUIApplication()
        let window = app.windows.firstMatch
        for _ in 0..<4 {
            let tabBar = app.tabBars.firstMatch
            let tabBarFrame = tabBar.exists ? tabBar.frame : .null
            let visibleBottom = tabBarFrame.minY > window.frame.midY ? tabBarFrame.minY : window.frame.maxY
            let overshoot = frame.maxY + 12 - visibleBottom
            guard overshoot > 0 else { return }
            let start = window.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.7))
            let distance = min(overshoot + 24, window.frame.height * 0.4)
            start.press(
                forDuration: 0.05,
                thenDragTo: start.withOffset(CGVector(dx: 0, dy: -distance)),
                withVelocity: .slow,
                thenHoldForDuration: 0.15
            )
        }
    }

    /// Taps a gallery entry's cover: 30 points in from a row's leading edge at its middle, where the row's cover
    /// sits, or the upper quarter of a grid card, which the card's full-width cover fills.
    func tapGalleryCover(
        grid: Bool,
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        if grid {
            tapGallery(at: CGVector(dx: 0.5, dy: 0.25), offset: .zero, name, file: file, line: line)
        } else {
            tapGallery(at: CGVector(dx: 0, dy: 0.5), offset: CGVector(dx: 30, dy: 0), name, file: file, line: line)
        }
    }

    private func tapGallery(
        at normalizedOffset: CGVector,
        offset: CGVector,
        _ name: String,
        file: StaticString,
        line: UInt
    ) {
        let becameHittable = waitUntilHittable(timeout: Self.hittableTimeout)
        if !becameHittable {
            attachScreenState("\(name) not hittable")
        }
        XCTAssertTrue(becameHittable, "\(name) never became hittable.", file: file, line: line)
        coordinate(withNormalizedOffset: normalizedOffset).withOffset(offset).tap()
    }

    /// Keeps the screen and the element's state with a failed wait, so a failure shows what covered or moved it.
    func attachScreenState(_ name: String) {
        XCTContext.runActivity(named: name) { activity in
            let screenshot = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
            screenshot.name = name
            screenshot.lifetime = .keepAlways
            activity.add(screenshot)
            let state = XCTAttachment(
                string: "exists: \(exists), hittable: \(exists && isHittable), frame: \(exists ? frame : .null)"
            )
            state.name = "\(name) state"
            state.lifetime = .keepAlways
            activity.add(state)
        }
    }

    /// Waits up to `timeout` for the element to become hittable, for example while a layout change settles.
    /// Returns whether it did, so the caller still asserts the condition.
    ///
    /// The element is asked only while it stands where the look before found it. XCTest wants the hit point in an
    /// element's snapshot to lie inside the snapshot's frame, and for an element whose layout is moving it may not.
    /// `isHittable` then does not answer false: it records a failure ("Failed to determine hittability of …") that
    /// ends the test at once. An expectation on `isHittable` asks all through a transition, and met that on Home as
    /// its sections landed (`GalleryCardUITests`, 2026-11-16). A Settings row on the hosted runner had met it before,
    /// with XCTest's reason: "Activation point invalid and no suggested hit points based on element frame"
    /// (`NativeVisualPolicyUITests`).
    func waitUntilHittable(timeout: TimeInterval) -> Bool {
        var previous: CGRect?
        return Polling.wait(timeout: timeout, interval: Self.restInterval) {
            let frame = frameInTree
            defer { previous = frame }
            guard let frame, frame == previous, !frame.isEmpty else { return false }
            return isHittable
        }
    }

    /// How far apart two looks at an element's frame are, for the element to count as at rest between them.
    private static let restInterval: TimeInterval = 0.2

    /// The element's frame, or `nil` while it is not in the tree. `frame` fails the test when it is asked of an
    /// element that has left the tree since the query found it; a snapshot throws instead.
    private var frameInTree: CGRect? {
        do {
            return try snapshot().frame
        } catch {
            // Not in the tree at this look. The wait looks again.
            return nil
        }
    }
}
