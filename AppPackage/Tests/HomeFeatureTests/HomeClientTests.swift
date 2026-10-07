import AppModels
import ComposableArchitecture
import CustomDump
import Foundation
@testable import HomeFeature
import Testing

// The live popular fetch arranges the hero carousel (17-04 owner decision): the ten longest
// titles, repeated trimmed titles removed, at most six, in an order drawn from the generator.
// A seeded generator makes that order reproducible here; the live client uses the system one.
struct HomeClientTests {
    @Test
    func carouselKeepsTheSixLongestTitlesInTheGeneratorsOrder() {
        let galleries = makeGalleries(titleLengths: [3, 12, 5, 11, 1, 10, 9, 2, 8, 7, 6, 4])
        var expected = ["1", "3", "5", "6", "8", "9"].compactMap({ gid in
            galleries.first(where: { $0.gid == gid })
        })
        var reference = SplitMix64(seed: 17)
        expected.shuffle(using: &reference)

        var generator = SplitMix64(seed: 17)
        let carousel = HomeClient.arrangedCarousel(galleries, using: &generator)

        expectNoDifference(carousel.map(\.gid), expected.map(\.gid))
    }

    @Test
    func carouselTakesTheTenLongestTitlesBeforeRemovingRepeats() {
        // Galleries 0–5 share one title and are among the ten longest, so only five distinct
        // titles survive; 10 and 11 are distinct but shorter than the ten, so they never enter.
        let repeatedTitle = String(repeating: "r", count: 30)
        var galleries = (0..<6).map({ makeGallery(gid: "\($0)", title: repeatedTitle) })
        galleries += [
            makeGallery(gid: "6", title: String(repeating: "f", count: 29)),
            makeGallery(gid: "7", title: String(repeating: "g", count: 28)),
            makeGallery(gid: "8", title: String(repeating: "h", count: 27)),
            makeGallery(gid: "9", title: String(repeating: "i", count: 26)),
            makeGallery(gid: "10", title: String(repeating: "j", count: 25)),
            makeGallery(gid: "11", title: String(repeating: "k", count: 24))
        ]
        var generator = SplitMix64(seed: 3)

        let carousel = HomeClient.arrangedCarousel(galleries, using: &generator)

        expectNoDifference(Set(carousel.map(\.gid)), ["0", "6", "7", "8", "9"])
    }

    @Test
    func carouselKeepsEveryDistinctTitleWhenFewerThanSix() {
        let galleries = makeGalleries(titleLengths: [4, 9, 2])
        var generator = SplitMix64(seed: 5)

        let carousel = HomeClient.arrangedCarousel(galleries, using: &generator)

        expectNoDifference(Set(carousel.map(\.gid)), ["0", "1", "2"])
    }

    // The reducer shows each list exactly as the client returns it. The popular titles are in
    // neither length order, so restoring the old in-reducer sort or shuffle would reorder them.
    @MainActor
    @Test
    func presentationShowsEveryListInTheClientsOrder() async {
        let popular = makeGalleries(titleLengths: [2, 9, 4, 12, 1, 7])
        let frontpage = [makeGallery(gid: "f0", title: "Front A"), makeGallery(gid: "f1", title: "Front B")]
        let appStorage = UserDefaults.inMemory
        let store = withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            TestStore(
                initialState: HomeReducer.State(),
                reducer: HomeReducer.init,
                withDependencies: {
                    $0.analyticsClient = .noop
                    $0.defaultAppStorage = appStorage
                    $0.homeClient = HomeClient(
                        fetchPopularGalleries: { (_: GalleryHost, _: AppModels.Filter) async throws(AppError) in
                            popular
                        },
                        fetchFrontpageGalleries: { (_: GalleryHost, _: AppModels.Filter) async throws(AppError) in
                            (pageNumber: PageNumber(), galleries: frontpage)
                        },
                        fetchToplistsGalleries: { (_: GalleryHost, catIndex: Int, _: Int?) async throws(AppError) in
                            (pageNumber: PageNumber(), galleries: [makeGallery(gid: "t\(catIndex)", title: "Top")])
                        }
                    )
                }
            )
        }
        store.exhaustivity = .off

        await store.send(.onPresented)
        await store.finish()
        await store.skipReceivedActions(strict: false)

        expectNoDifference(store.state.popularGalleries.map(\.gid), ["0", "1", "2", "3", "4", "5"])
        expectNoDifference(store.state.currentCardID, "1")
        expectNoDifference(store.state.frontpageGalleries.map(\.gid), ["f0", "f1"])
        expectNoDifference(
            store.state.toplistsGalleries.mapValues({ $0.map(\.gid) }),
            Dictionary(
                uniqueKeysWithValues: ToplistsType.allCases.map({ ($0.categoryIndex, ["t\($0.categoryIndex)"]) })
            )
        )
    }
}

/// SplitMix64, a small seedable generator, so a shuffle's order is reproducible.
private struct SplitMix64: RandomNumberGenerator {
    private var state: UInt64

    init(seed: UInt64) {
        state = seed
    }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }
}

/// One gallery per length, with gids `"0"`, `"1"`, … in input order and titles of that many letters.
private func makeGalleries(titleLengths: [Int]) -> [Gallery] {
    titleLengths.enumerated().map({ offset, length in
        makeGallery(gid: "\(offset)", title: String(repeating: "a", count: length))
    })
}

private func makeGallery(gid: String, title: String) -> Gallery {
    Gallery(
        gid: gid,
        token: "token",
        title: title,
        rating: 4,
        tags: [],
        category: .nonH,
        pageCount: 10,
        postedDate: Date(timeIntervalSince1970: 0),
        coverURL: nil,
        galleryURL: nil
    )
}
