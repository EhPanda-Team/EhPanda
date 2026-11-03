import CoreGraphics
import CustomDump
@testable import GalleryListComponents
import Testing

@MainActor
struct GalleryRowAnchorTrackerTests {
    /// Bars cover y < 100 and y >= 700.
    private let clearArea = CGRect(x: 0, y: 100, width: 400, height: 600)

    private func row(_ minY: CGFloat) -> CGRect {
        CGRect(x: 16, y: minY, width: 368, height: 120)
    }

    private func show(_ id: String, at minY: CGFloat, in tracker: GalleryRowAnchorTracker) {
        tracker.updateRow(id, isVisible: true)
        tracker.updateRow(id, frame: row(minY))
    }

    @Test
    func trackingFollowsTheRowThePersonSeesFirst() {
        let tracker = GalleryRowAnchorTracker(restoring: nil)
        tracker.updateClearArea(clearArea)
        show("a", at: 35, in: tracker)
        show("b", at: 170, in: tracker)
        expectNoDifference(tracker.visibleID, "b")
        tracker.updateRow("a", frame: row(60))
        expectNoDifference(tracker.visibleID, "a")
    }

    @Test
    func aRowScrolledOutOfTheListNoLongerCounts() {
        let tracker = GalleryRowAnchorTracker(restoring: nil)
        tracker.updateClearArea(clearArea)
        show("a", at: 110, in: tracker)
        show("b", at: 240, in: tracker)
        // A jump leaves "a" with a stale frame it never updates again.
        tracker.updateRow("a", isVisible: false)
        tracker.updateRow("b", frame: row(105))
        expectNoDifference(tracker.visibleID, "b")
    }

    @Test
    func aRebuiltListKeepsItsAnchorUntilTheAnchorArrivesUncovered() {
        let tracker = GalleryRowAnchorTracker(restoring: "c")
        tracker.updateClearArea(clearArea)
        // The rebuilt list first lays out from its top; those rows must not replace the anchor.
        show("a", at: 100, in: tracker)
        show("c", at: 360, in: tracker)
        expectNoDifference(tracker.visibleID, nil)
        expectNoDifference(tracker.beginRestoration(availableIDs: ["a", "b", "c"]), "c")
        show("a", at: 120, in: tracker)
        expectNoDifference(tracker.visibleID, nil, "A frame below the top predates the scroll.")
        tracker.updateRow("a", isVisible: false)
        tracker.updateRow("c", frame: row(100))
        expectNoDifference(tracker.visibleID, "c")
        expectNoDifference(tracker.revealID, nil)
        expectNoDifference(tracker.beginRestoration(availableIDs: ["a", "b", "c"]), nil, "Restoration runs once.")
    }

    @Test
    func anAnchorLeftUnderTheNavigationBarIsRevealed() {
        let tracker = GalleryRowAnchorTracker(restoring: "c")
        tracker.updateClearArea(clearArea)
        _ = tracker.beginRestoration(availableIDs: ["b", "c", "d"])
        show("c", at: 20, in: tracker)
        expectNoDifference(tracker.revealID, "c")
        show("c", at: 100, in: tracker)
        show("d", at: 230, in: tracker)
        expectNoDifference(tracker.visibleID, "c")
    }

    @Test
    func anAnchorThatCannotReachTheTopResumesTrackingAtTheDeadline() {
        let tracker = GalleryRowAnchorTracker(restoring: "z")
        tracker.updateClearArea(clearArea)
        _ = tracker.beginRestoration(availableIDs: ["y", "z"])
        show("y", at: 450, in: tracker)
        show("z", at: 580, in: tracker)
        expectNoDifference(tracker.visibleID, nil)
        tracker.endRestoration()
        expectNoDifference(tracker.visibleID, "y")
        expectNoDifference(tracker.revealID, nil)
    }

    @Test
    func aMissingAnchorTracksImmediately() {
        let tracker = GalleryRowAnchorTracker(restoring: "gone")
        tracker.updateClearArea(clearArea)
        show("a", at: 100, in: tracker)
        expectNoDifference(tracker.beginRestoration(availableIDs: ["a"]), nil)
        expectNoDifference(tracker.visibleID, "a")
    }
}
