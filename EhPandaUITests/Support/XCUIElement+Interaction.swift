import XCTest

@MainActor
extension XCUIElement {
    /// Waits for a control to accept a tap, including any preceding menu or sheet transition.
    func tapWhenHittable(
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        XCTAssertTrue(
            waitUntilHittable(timeout: 10),
            "\(name) never became hittable.",
            file: file,
            line: line
        )
        tap()
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
