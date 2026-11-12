import CoreGraphics
import CustomDump
import GalleryListComponents
import Testing

struct GalleryScrollAnchorTests {
    @Test
    func paginationAndReorderingKeepTheSameGallery() {
        expectNoDifference(
            GalleryScrollAnchor.retaining("b", previousIDs: ["a", "b"], currentIDs: ["a", "b", "c", "d"]), "b"
        )
        expectNoDifference(
            GalleryScrollAnchor.retaining("b", previousIDs: ["a", "b", "c"], currentIDs: ["c", "b", "a"]), "b"
        )
    }

    @Test
    func removingTheVisibleGalleryKeepsTheNearestSurvivingNeighbor() {
        expectNoDifference(
            GalleryScrollAnchor.retaining("c", previousIDs: ["a", "b", "c", "d"], currentIDs: ["a", "d"]), "d"
        )
        expectNoDifference(
            GalleryScrollAnchor.retaining("c", previousIDs: ["a", "b", "c", "d"], currentIDs: ["b", "d"]), "b"
        )
    }

    @Test
    func replacingTheCollectionUsesItsFirstGalleryAndEmptyRemainsEmpty() {
        expectNoDifference(GalleryScrollAnchor.retaining("b", previousIDs: ["a", "b"], currentIDs: ["x", "y"]), "x")
        expectNoDifference(GalleryScrollAnchor.retaining("b", previousIDs: ["a", "b"], currentIDs: []), nil)
        expectNoDifference(GalleryScrollAnchor.retaining(nil, previousIDs: [], currentIDs: ["a", "b"]), nil)
    }

    /// A phone-like list: bars cover y < 100 and y >= 700.
    private let clearArea = CGRect(x: 0, y: 100, width: 400, height: 600)

    private func row(_ minY: CGFloat, height: CGFloat = 120) -> CGRect {
        CGRect(x: 16, y: minY, width: 368, height: height)
    }

    @Test
    func theTopVisibleGalleryIsTheHighestRowWhoseCenterClearsTheBar() {
        let frames = ["a": row(-30), "b": row(100), "c": row(230), "d": row(360)]
        expectNoDifference(GalleryScrollAnchor.topVisibleID(rowFrames: frames, clearArea: clearArea), "b")
    }

    @Test
    func aRowMostlyCoveredByTheNavigationBarIsNotTheAnchor() {
        // Its center (y 95) is still under the bar although a sliver shows below it.
        let mostlyCovered = ["a": row(35), "b": row(165)]
        expectNoDifference(GalleryScrollAnchor.topVisibleID(rowFrames: mostlyCovered, clearArea: clearArea), "b")
        // Once more than half of it clears the bar, the person sees it first.
        let mostlyVisible = ["a": row(45), "b": row(175)]
        expectNoDifference(GalleryScrollAnchor.topVisibleID(rowFrames: mostlyVisible, clearArea: clearArea), "a")
    }

    @Test
    func rowsUnderTheTabBarOrMissingAreNeverTheAnchor() {
        expectNoDifference(
            GalleryScrollAnchor.topVisibleID(rowFrames: ["z": row(650)], clearArea: clearArea), nil
        )
        expectNoDifference(GalleryScrollAnchor.topVisibleID(rowFrames: [:], clearArea: clearArea), nil)
        // Ties resolve by identifier, so the anchor never flips between equal frames.
        expectNoDifference(
            GalleryScrollAnchor.topVisibleID(rowFrames: ["y": row(120), "x": row(120)], clearArea: clearArea), "x"
        )
    }

    @Test
    func aRestoredRowIsUncoveredOnlyWhenNoBarHidesAnyOfIt() {
        #expect(GalleryScrollAnchor.isUncovered(rowFrame: row(100), clearArea: clearArea))
        #expect(GalleryScrollAnchor.isUncovered(rowFrame: row(99.5), clearArea: clearArea))
        #expect(GalleryScrollAnchor.isUncovered(rowFrame: row(580), clearArea: clearArea))
        #expect(!GalleryScrollAnchor.isUncovered(rowFrame: row(60), clearArea: clearArea))
        #expect(!GalleryScrollAnchor.isUncovered(rowFrame: row(600), clearArea: clearArea))
    }
}
