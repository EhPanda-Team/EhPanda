import AnalyticsClient
import AppModels
import ComposableArchitecture
import CustomDump
import Foundation
@testable import HomeFeature
import Sharing
import Testing

// Exact-sequence proof for every HomeFeature emission site. Each case drives its reducer through a
// store whose analytics client is a `LockIsolated`-backed spy — `.noop` with its `send` closure
// replaced by a collector — and asserts the *sequence* of recorded signals, not merely that
// something was recorded.
//
// The two destination sweeps are parameterized over the source enums' `allCases` rather than a hand
// list, so a sixth Home destination both fails to compile at the expected-mapping switch and adds an
// unmatched argument to the sweep — a new screen cannot ship silently unmeasured (T-14-14).
//
// Each store is torn down with `skipInFlightEffects` alone: the Home-level emission is merged with a
// `.send` presentation action, so flushing in-flight effects records the signal while leaving the
// buffered presentation action unprocessed. That keeps a pushed sub-screen's network fetch from
// firing (those requests take no injectable session — see HomePresentationLifecycleTests).
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
@Suite
struct AnalyticsEmissionTests {

    // MARK: Home sections (HomeReducer)

    // The section-tap destinations: sweeping `HomeSectionType.allCases` proves every list section
    // emits exactly one home-section signal carrying the section it maps to.
    @MainActor
    @Test(arguments: HomeSectionType.allCases)
    func tappingASectionDestinationRecordsOneHomeSectionSignal(_ type: HomeSectionType) async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeHomeStore(analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.sectionTapped(type))
        await store.skipInFlightEffects(strict: false)

        expectNoDifference(recorded.value, [.homeSectionViewed(Self.expectedSection(for: type))])
    }

    // The misc-grid destinations: sweeping `HomeMiscGridType.allCases` proves the other three
    // sections emit too. Together the two sweeps cover all five sections D-05 family 1 names.
    @MainActor
    @Test(arguments: HomeMiscGridType.allCases)
    func tappingAMiscDestinationRecordsOneHomeSectionSignal(_ type: HomeMiscGridType) async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeHomeStore(analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.miscTapped(type))
        await store.skipInFlightEffects(strict: false)

        expectNoDifference(recorded.value, [.homeSectionViewed(Self.expectedSection(for: type))])
    }

    // MARK: Gallery detail push (HomeReducer)

    @MainActor
    @Test
    func pushingAGalleryDetailRecordsOneSignalMatchingTheFixture() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let fixture = sentinelGallery()
        let expected = TagNamespaceCounts(tags: fixture.tags)
        let store = makeHomeStore(analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.pushGalleryDetail(fixture))
        await store.skipInFlightEffects(strict: false)

        expectNoDifference(
            recorded.value,
            [.galleryDetailOpened(category: fixture.category, tagNamespaces: expected)]
        )
    }

    @MainActor
    @Test
    func pushedGalleryDetailSignalCarriesNoFixtureTitleOrTagText() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let fixture = sentinelGallery()
        let store = makeHomeStore(analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.pushGalleryDetail(fixture))
        await store.skipInFlightEffects(strict: false)

        // Reflect over the whole recorded signal graph — every stored leaf, public or not — and prove
        // the fixture's distinctive title and tag text survive nowhere in it. A closed `Category` plus
        // exact namespace counts cannot carry either sentinel; this pins that (T-14-01).
        let leaves = Mirror(reflecting: recorded.value).leafRenderings
        #expect(leaves.contains(where: { $0.contains(Self.sentinelTitle) }) == false)
        #expect(leaves.contains(where: { $0.contains(Self.sentinelTagText) }) == false)
    }

    // MARK: Filter and quick-search panels (sub-screen reducers)

    @MainActor
    @Test
    func openingTheFrontpageFilterPanelRecordsOneSignalNamingFrontpage() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        await withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            let store = TestStore(initialState: .init(), reducer: FrontpageReducer.init) {
                $0.analyticsClient = .recording(into: recorded)
                $0.defaultAppStorage = UserDefaults.inMemory
                $0.hapticsClient = .noop
            }
            store.exhaustivity = .off(showSkippedAssertions: false)

            await store.send(.filtersButtonTapped)
            await store.skipInFlightEffects(strict: false)

            expectNoDifference(recorded.value, [.filterPanelOpened(.frontpage)])
        }
    }

    @MainActor
    @Test
    func openingThePopularFilterPanelRecordsOneSignalNamingPopular() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        await withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            let store = TestStore(initialState: .init(), reducer: PopularReducer.init) {
                $0.analyticsClient = .recording(into: recorded)
                $0.defaultAppStorage = UserDefaults.inMemory
                $0.hapticsClient = .noop
            }
            store.exhaustivity = .off(showSkippedAssertions: false)

            await store.send(.filtersButtonTapped)
            await store.skipInFlightEffects(strict: false)

            expectNoDifference(recorded.value, [.filterPanelOpened(.popular)])
        }
    }

    @MainActor
    @Test
    func openingTheWatchedFilterPanelRecordsOneSignalNamingWatched() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        await withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            let store = TestStore(initialState: .init(), reducer: WatchedReducer.init) {
                $0.analyticsClient = .recording(into: recorded)
                $0.cookieClient = .noop
                $0.defaultAppStorage = UserDefaults.inMemory
                $0.downloadClient = .noop
                $0.hapticsClient = .noop
            }
            store.exhaustivity = .off(showSkippedAssertions: false)

            await store.send(.filtersButtonTapped)
            await store.skipInFlightEffects(strict: false)

            expectNoDifference(recorded.value, [.filterPanelOpened(.watched)])
        }
    }

    @MainActor
    @Test
    func openingTheWatchedQuickSearchPanelRecordsOneQuickSearchSignal() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        await withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            let store = TestStore(initialState: .init(), reducer: WatchedReducer.init) {
                $0.analyticsClient = .recording(into: recorded)
                $0.cookieClient = .noop
                $0.defaultAppStorage = UserDefaults.inMemory
                $0.downloadClient = .noop
                $0.hapticsClient = .noop
            }
            store.exhaustivity = .off(showSkippedAssertions: false)

            await store.send(.quickSearchButtonTapped)
            await store.skipInFlightEffects(strict: false)

            expectNoDifference(recorded.value, [.quickSearchPanelOpened(.watched)])
        }
    }
}

// MARK: Expected mappings

private extension AnalyticsEmissionTests {
    // Mirrors the production mapping in `HomeReducer+Body.swift`, kept exhaustive with no `default:`
    // arm on purpose: a sixth destination fails to compile here, so the sweep cannot pass by folding
    // a new screen into a neighbour.
    static func expectedSection(for type: HomeSectionType) -> HomeSection {
        switch type {
        case .frontpage:
            return .frontpage
        case .toplists:
            return .toplists
        }
    }

    static func expectedSection(for type: HomeMiscGridType) -> HomeSection {
        switch type {
        case .popular:
            return .popular
        case .watched:
            return .watched
        case .history:
            return .history
        }
    }
}

// MARK: Spy

private extension AnalyticsClient {
    // The `LockIsolated` capture idiom (AppActivityLogsReducerTests / AnalyticsClientGateTests): take
    // the inert `.noop` client and replace its one `send` closure with a collector, so a test asserts
    // exactly which signals crossed the reducer → client boundary and in what order. `start` stays
    // inert. This relies on the client's `var` closure properties.
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
    func sentinelGallery() -> Gallery {
        Gallery(
            gid: "9001",
            token: "sentinel-token",
            title: Self.sentinelTitle,
            rating: 4,
            tags: [
                GalleryTag(rawNamespace: "female", contents: [
                    tagContent(Self.sentinelTagText + "-a"),
                    tagContent(Self.sentinelTagText + "-b")
                ]),
                GalleryTag(rawNamespace: "artist", contents: [
                    tagContent(Self.sentinelTagText + "-c")
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

    func tagContent(_ text: String) -> GalleryTag.Content {
        GalleryTag.Content(rawNamespace: "female", text: text, isVotedUp: false, isVotedDown: false)
    }

    @MainActor
    func makeHomeStore(analyticsClient: AnalyticsClient) -> TestStoreOf<HomeReducer> {
        let appStorage = UserDefaults.inMemory

        return withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            var state = HomeReducer.State()
            // Populated so the Home root's own presentation load stays out of these assertions.
            state.popularGalleries = [.preview]

            return TestStore(
                initialState: state,
                reducer: HomeReducer.init,
                withDependencies: {
                    $0.analyticsClient = analyticsClient
                    $0.cookieClient = .noop
                    $0.date = .constant(.init(timeIntervalSince1970: 0))
                    $0.defaultAppStorage = appStorage
                    $0.downloadClient = .noop
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
