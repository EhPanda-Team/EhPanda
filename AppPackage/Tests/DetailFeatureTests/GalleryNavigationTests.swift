import Testing
import AppModels
@testable import DetailFeature
import ComposableArchitecture

@Suite
struct GalleryNavigationTests {
    // A minimal gallery whose `id` ("1") drives the detail route key that dedup compares.
    private let galleryOne = Gallery(
        gid: "1", token: "", title: "", rating: 0, tags: [],
        category: .doujinshi, uploader: "", pageCount: 1,
        postedDate: .distantPast, coverURL: nil, galleryURL: nil
    )

    // appendGuardingDuplicate skips only an adjacent identical element, so a rapid double-activation
    // pushes one screen while a legitimate same-gid re-push through a deeper screen still appends.
    @Test
    func appendGuardingDuplicateSkipsOnlyAdjacentDuplicates() {
        var path = StackState<GalleryPath.State>()

        path.appendGuardingDuplicate(.detail(.init(gallery: galleryOne)))
        #expect(path.count == 1)

        // A second identical push (double-tap) is skipped.
        path.appendGuardingDuplicate(.detail(.init(gallery: galleryOne)))
        #expect(path.count == 1)

        // A different screen is appended.
        path.appendGuardingDuplicate(.comments(.init(galleryURL: .mock)))
        #expect(path.count == 2)

        // The same detail after a non-adjacent screen is appended (only the top is compared).
        path.appendGuardingDuplicate(.detail(.init(gallery: galleryOne)))
        #expect(path.count == 3)
    }
}
