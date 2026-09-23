import XCTest

@MainActor
extension XCUIElement {
    /// Waits for a control to accept a tap, including any preceding menu or sheet transition.
    func tapWhenHittable(
        _ name: String,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let becomesHittable = XCTNSPredicateExpectation(
            predicate: NSPredicate(format: "isHittable == true"),
            object: self
        )
        XCTAssertEqual(
            XCTWaiter.wait(for: [becomesHittable], timeout: 10),
            .completed,
            "\(name) never became hittable.",
            file: file,
            line: line
        )
        tap()
    }
}
