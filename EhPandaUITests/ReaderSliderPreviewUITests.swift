import AutomationIdentifiers
import Foundation
import XCTest

/// The reader's page preview and the slider that opens it. A hold on the slider's thumb opens the preview; a hold on
/// the track away from the thumb is the system slider's own gesture there and opens nothing.
///
/// A hold is a blocking call, so a task on the main actor asks whether the preview is on screen while it lasts.
@MainActor
final class ReaderSliderPreviewUITests: XCTestCase {
    private static let holdDuration = 2.5
    /// The preview's frame is the labels' alone, a line of text, while it is away and holds the page images as well
    /// while it is shown.
    private static let shownHeight = 60.0

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    func testHoldingTheThumbShowsThePreview() throws {
        let app = try openReaderWithPanel()
        let slider = try middleSlider(in: app)
        let thumb = coordinate(onSlider: slider, atValue: 0.5)

        let sighting = holdAndWatchPreview(at: thumb, in: app)
        XCTAssertTrue(sighting.seen, "Holding the slider's thumb did not show the page preview.")
    }

    func testHoldingTheTrackAwayFromTheThumbShowsNoPreview() throws {
        let app = try openReaderWithPanel()
        let slider = try middleSlider(in: app)

        for value in [0.85, 0.15] {
            let track = coordinate(onSlider: slider, atValue: value)
            let sighting = holdAndWatchPreview(at: track, in: app)
            XCTAssertFalse(
                sighting.seen,
                "Holding the track at \(value), away from the thumb, showed the page preview."
            )
        }
    }

    // MARK: Helpers

    private func openReaderWithPanel() throws -> XCUIApplication {
        let app = XCUIApplication()
        let pageURL = try XCTUnwrap(UITestConstants.singlePageURL(scheme: "ehpanda"))
        try app.openCold(pageURL)
        app.requireForeground()
        _ = app.requireElement(AccessibilityIdentifiers.readingView)
        let reader = ReaderPageProbe(app: app)
        reader.showPanel()
        // The direction persists between launches and the slider runs the way the pages do. A reader that another
        // test left right to left has page 1 at the slider's right end, and adjusting the slider there leaves the
        // thumb where it is: both cases then hold a track with no thumb in its middle.
        reader.setDirection(.vertical)
        reader.showPanel()
        return app
    }

    /// The slider with its thumb in the middle of the track, so the thumb and both ends of the track are apart.
    private func middleSlider(in app: XCUIApplication) throws -> XCUIElement {
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 10), "The panel did not expose its page slider.")
        slider.adjust(toNormalizedSliderPosition: 0.5)
        // Both cases stand on this: a hold in the middle of the track is a hold on the thumb.
        XCTAssertEqual(
            slider.normalizedSliderPosition, 0.5, accuracy: 0.1,
            "The slider's thumb is not in the middle of its track."
        )
        // Dragging the thumb shows the preview; it goes when the finger does.
        let preview = previewElement(in: app)
        XCTAssertTrue(
            Polling.wait { !preview.exists || preview.frame.height < Self.shownHeight },
            "The preview was showing before any touch: \(preview.frame)."
        )
        return slider
    }

    /// A point of the slider at `value` of its track. The thumb is inset by its radius at both ends.
    private func coordinate(onSlider slider: XCUIElement, atValue value: Double) -> XCUICoordinate {
        let frame = slider.frame
        let inset = 16.0
        let position = frame.minX + inset + (frame.width - 2 * inset) * value
        let origin = slider.coordinate(withNormalizedOffset: .zero)
        return origin.withOffset(CGVector(dx: position - frame.minX, dy: frame.height / 2))
    }

    private func previewElement(in app: XCUIApplication) -> XCUIElement {
        app.descendants(matching: .any).matching(identifier: AccessibilityIdentifiers.readingSliderPreview).firstMatch
    }

    private struct Sighting {
        var seen = false
        var after: TimeInterval?
    }

    /// Holds still at `point` while a task on the main actor watches for the preview.
    ///
    /// Elements belong to the main actor, so the watcher asks from there and not from a second thread. The hold
    /// blocks its caller, but XCTest turns the main run loop while it waits for the touch to end, and the task runs
    /// in those turns. The thumb's case fails if it ever stops doing so, since the task then sees nothing.
    private func holdAndWatchPreview(at point: XCUICoordinate, in app: XCUIApplication) -> Sighting {
        let preview = previewElement(in: app)
        let started = Date()
        var sighting = Sighting()
        let watcher = Task {
            while !Task.isCancelled, !sighting.seen {
                if preview.exists && preview.frame.height >= Self.shownHeight {
                    sighting = Sighting(seen: true, after: Date().timeIntervalSince(started))
                }
                try await Task.sleep(for: .milliseconds(50))
            }
        }
        point.press(forDuration: Self.holdDuration)
        watcher.cancel()
        return sighting
    }
}
