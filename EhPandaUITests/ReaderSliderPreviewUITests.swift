import Foundation
import Synchronization
import XCTest

/// The reader's page preview and the slider that opens it. A hold on the slider's thumb opens the preview; a hold on
/// the track away from the thumb is the system slider's own gesture there and opens nothing.
///
/// A hold is a blocking call, so a second thread asks whether the preview is on screen while it lasts.
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
        let reader = app.requireElement("reading_view")
        let indicator = app.staticTexts.matching(identifier: "reading_page_indicator").firstMatch
        if !indicator.exists {
            reader.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.35)).tap()
        }
        XCTAssertTrue(indicator.waitForExistence(timeout: 10), "The reader did not show its panel.")
        return app
    }

    /// The slider with its thumb in the middle of the track, so the thumb and both ends of the track are apart.
    private func middleSlider(in app: XCUIApplication) throws -> XCUIElement {
        let slider = app.sliders.firstMatch
        XCTAssertTrue(slider.waitForExistence(timeout: 10), "The panel did not expose its page slider.")
        slider.adjust(toNormalizedSliderPosition: 0.5)
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
        app.descendants(matching: .any).matching(identifier: "reading_slider_preview").firstMatch
    }

    private struct Sighting {
        var seen = false
        var after: TimeInterval?
    }

    /// What the watching thread saw, shared with it.
    private final class SightingBox: Sendable {
        private let sighting = Mutex(Sighting())
        func record(after: TimeInterval) {
            sighting.withLock { current in
                if !current.seen { current = Sighting(seen: true, after: after) }
            }
        }
        var value: Sighting { sighting.withLock({ $0 }) }
    }

    /// Holds still at `point` while another thread watches for the preview.
    private func holdAndWatchPreview(at point: XCUICoordinate, in app: XCUIApplication) -> Sighting {
        let box = SightingBox()
        nonisolated(unsafe) let preview = previewElement(in: app)
        let started = Date()
        let watcher = DispatchGroup()
        watcher.enter()
        DispatchQueue.global().async {
            while Date().timeIntervalSince(started) < Self.holdDuration + 1 {
                if preview.exists && preview.frame.height >= Self.shownHeight {
                    box.record(after: Date().timeIntervalSince(started))
                }
                Thread.sleep(forTimeInterval: 0.05)
            }
            watcher.leave()
        }
        point.press(forDuration: Self.holdDuration)
        watcher.wait()
        return box.value
    }
}
