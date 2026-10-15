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
}
