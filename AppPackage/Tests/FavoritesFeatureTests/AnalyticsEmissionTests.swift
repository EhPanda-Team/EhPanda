import AnalyticsClient
import AppModels
import ComposableArchitecture
@testable import FavoritesFeature
import Foundation
import Testing

// Exact-sequence proof for FavoritesFeature's two emission sites: the gallery-detail push and the
// quick-search panel. Each drives the reducer through a store whose analytics client is a
// `LockIsolated`-backed spy and asserts the recorded sequence.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
@Suite
struct AnalyticsEmissionTests {

    // MARK: Gallery detail push

    @MainActor
    @Test
    func pushingAGalleryDetailRecordsOneSignalMatchingTheFixture() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let fixture = Self.sentinelGallery()
        let expected = TagNamespaceCounts(tags: fixture.tags)
        let store = makeFavoritesStore(analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.pushGalleryDetail(fixture))
        await store.skipInFlightEffects(strict: false)

        expectNoDifference(
            recorded.value,
            [.galleryDetailOpened(category: fixture.category, tagNamespaces: expected)]
        )
    }

    // Reflect over the whole recorded signal graph and prove the fixture's distinctive title and tag
    // text survive nowhere. A closed `Category` plus exact per-namespace counts cannot carry either
    // sentinel (T-14-01).
    @MainActor
    @Test
    func pushedGalleryDetailSignalCarriesNoFixtureTitleOrTagText() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let fixture = Self.sentinelGallery()
        let store = makeFavoritesStore(analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.pushGalleryDetail(fixture))
        await store.skipInFlightEffects(strict: false)

        #expect(recorded.value.isEmpty == false)
        let leaves = Mirror(reflecting: recorded.value).leafRenderings
        #expect(leaves.contains(where: { $0.contains(Self.sentinelTitle) }) == false)
        #expect(leaves.contains(where: { $0.contains(Self.sentinelTagText) }) == false)
    }

    // MARK: Quick-search panel

    @MainActor
    @Test
    func openingTheQuickSearchPanelRecordsOneSignalNamingFavorites() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeFavoritesStore(analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.quickSearchButtonTapped)
        await store.skipInFlightEffects(strict: false)

        expectNoDifference(recorded.value, [.quickSearchPanelOpened(.favorites)])
    }
}

// MARK: Spy

private extension AnalyticsClient {
    // The `LockIsolated` capture idiom: take the inert `.noop` client and replace its one `send`
    // closure with a collector, so a test asserts exactly which signals crossed the reducer → client
    // boundary and in what order. `start` stays inert. Relies on the client's `var` closure properties.
    static func recording(into recorded: LockIsolated<[AnalyticsSignal]>) -> Self {
        var client = AnalyticsClient.noop
        client.send = { signal in recorded.withValue({ $0.append(signal) }) }
        return client
    }
}

// MARK: Fixtures and stores

private extension AnalyticsEmissionTests {
    static let sentinelTitle = "SENTINEL_TITLE_must_never_leak"
    static let sentinelTagText = "SENTINEL_TAGTEXT_must_never_leak"

    // A gallery whose title and tag text are distinctive sentinels, with two recognized namespaces
    // carrying known counts (female: 2, artist: 1) so the emitted `TagNamespaceCounts` is exactly
    // predictable while the sentinels give the reflection assertion something to hunt for. No
    // `galleryURL`, so the pushed detail's fetch short-circuits and no network request is made.
    static func sentinelGallery() -> Gallery {
        Gallery(
            gid: "9001",
            token: "sentinel-token",
            title: sentinelTitle,
            rating: 4,
            tags: [
                GalleryTag(rawNamespace: "female", contents: [
                    tagContent(sentinelTagText + "-a"),
                    tagContent(sentinelTagText + "-b")
                ]),
                GalleryTag(rawNamespace: "artist", contents: [
                    tagContent(sentinelTagText + "-c")
                ])
            ],
            category: .manga,
            uploader: "Uploader",
            pageCount: 10,
            postedDate: Date(timeIntervalSince1970: 0),
            coverURL: nil,
            galleryURL: nil
        )
    }

    static func tagContent(_ text: String) -> GalleryTag.Content {
        GalleryTag.Content(rawNamespace: "female", text: text, isVotedUp: false, isVotedDown: false)
    }

    @MainActor
    func makeFavoritesStore(analyticsClient: AnalyticsClient) -> TestStoreOf<FavoritesReducer> {
        let appStorage = UserDefaults.inMemory

        return withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            TestStore(
                initialState: FavoritesReducer.State(),
                reducer: FavoritesReducer.init,
                withDependencies: {
                    $0.analyticsClient = analyticsClient
                    $0.cookieClient = .noop
                    $0.date = .constant(.init(timeIntervalSince1970: 0))
                    $0.defaultAppStorage = appStorage
                    $0.downloadClient = .noop
                    $0.hapticsClient = .noop
                }
            )
        }
    }
}

// Mirrors plan 14-03's `ContentLeakProbe` reflection helper. That helper lives in the
// `AnalyticsClientTests` target, which this target cannot import; the walk is reproduced verbatim
// here rather than reimplemented differently, so both privacy proofs reflect over values the same
// way — reaching every stored leaf, including ones the public API never exposes.
private extension Mirror {
    var leafRenderings: [String] {
        children.flatMap({ child in
            let nested = Mirror(reflecting: child.value).leafRenderings
            return nested.isEmpty ? [String(describing: child.value)] : nested
        })
    }
}
