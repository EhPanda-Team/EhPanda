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
    func waitUntilHittable(timeout: TimeInterval) -> Bool {
        let becomesHittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: self
        )
        return XCTWaiter.wait(for: [becomesHittable], timeout: timeout) == .completed
    }
}
