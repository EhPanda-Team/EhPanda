import AppModels
import Testing

@Suite
struct GalleryPagingTests {
    @Test
    func appendNewSkipsListedGalleriesAndRepeatsWithinThePage() {
        let galleries = Gallery.previews(count: 3)
        var list = [galleries[0], galleries[1]]

        let added = list.appendNew([galleries[1], galleries[2], galleries[2]])

        #expect(added == 1)
        #expect(list == galleries)
    }

    @Test
    func appendNewOfAPageOfRepeatsAddsNothing() {
        let galleries = Gallery.previews(count: 2)
        var list = galleries

        #expect(list.appendNew(galleries.reversed()) == 0)
        #expect(list == galleries)
    }

    @Test(arguments: [
        // A cursor pager moves on when the site gives a new cursor, and only then.
        Advance(PageNumber(nextCursor: "a"), PageNumber(nextCursor: "b"), advances: true),
        Advance(PageNumber(nextCursor: "a"), PageNumber(nextCursor: "a"), advances: false),
        Advance(PageNumber(nextCursor: "a"), PageNumber(), advances: false),
        // A numbered pager moves on by its page index, up to the last page.
        Advance(PageNumber(current: 0, maximum: 2), PageNumber(current: 1, maximum: 2), advances: true),
        Advance(PageNumber(current: 1, maximum: 2), PageNumber(current: 1, maximum: 2), advances: false),
        Advance(PageNumber(current: 1, maximum: 2), PageNumber(current: 2, maximum: 2), advances: false)
    ])
    func advancesOnlyWhenTheSitesPagingMovesOnAndHasMore(_ advance: Advance) {
        #expect(advance.page.advances(from: advance.previous) == advance.advances)
    }

    struct Advance: Sendable, CustomTestStringConvertible {
        let previous: PageNumber
        let page: PageNumber
        let advances: Bool

        init(_ previous: PageNumber, _ page: PageNumber, advances: Bool) {
            self.previous = previous
            self.page = page
            self.advances = advances
        }

        var testDescription: String {
            "\(previous) -> \(page): \(advances)"
        }
    }
}
