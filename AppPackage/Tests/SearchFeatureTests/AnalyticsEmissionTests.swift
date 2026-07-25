import AnalyticsClient
import AppModels
import ComposableArchitecture
import Foundation
import NetworkingFeature
import QuickSearchFeature
@testable import SearchFeature
import Testing

// Exact-sequence proof for the search family's emission sites. Each case drives its reducer through a
// store whose analytics client is a `LockIsolated`-backed spy — `.noop` with its `send` closure
// replaced by a collector — and asserts the *sequence* of recorded signals, not merely that
// something was recorded.
//
// The search family handles raw user-authored text, so two assertions here are the phase's most
// load-bearing: the performed-search signal is reflected over in full and proven to carry no part of
// a sentinel keyword, and the history-keyword action — which carries the raw keyword — is proven to
// record nothing at all. Both use the reflection helper reproduced at the foot of this file.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
@Suite
struct AnalyticsEmissionTests {

    // MARK: Performed search (SearchReducer)

    // The performed-search signal is emitted from the fetch-completion case as a reduced `SearchShape`
    // and a result bucket. This drives the failure arm — a search that returned nothing is still a
    // performed search worth counting — and pins the zero bucket and the shape reduced from the state's
    // last-performed keyword. The success arm is driven below, now that the wave-6 manifest freeze is
    // lifted and this target carries the `NetworkingFeature` edge the fixture needs (14-17).
    @MainActor
    @Test
    func aFailedSearchRecordsOnePerformedSignalWithAZeroBucket() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeSearchStore(keyword: Self.sentinelKeyword, analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.fetchGalleriesDone(.failure(.notFound)))
        await store.skipInFlightEffects(strict: false)

        expectNoDifference(
            recorded.value,
            [.searchPerformed(shape: SearchShape(keyword: Self.sentinelKeyword), resultCount: .zero)]
        )
    }

    // The success arm: the result bucket derives from `response.galleries.count`, so three fixture
    // galleries must land in the 2-5 bucket. Only the count matters — the galleries' content never
    // reaches the signal, which the sentinel sweep below proves separately. Deferred from 14-12 by
    // the wave-6 manifest freeze; the `NetworkingFeature` test edge closing that gap landed in 14-17.
    @MainActor
    @Test
    func aSuccessfulSearchRecordsThePerformedSignalWithTheResultBucket() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeSearchStore(keyword: Self.sentinelKeyword, analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.fetchGalleriesDone(.success(GalleriesResult(
            pageNumber: PageNumber(),
            galleries: [.preview, .preview, .preview]
        ))))
        await store.skipInFlightEffects(strict: false)

        expectNoDifference(
            recorded.value,
            [.searchPerformed(shape: SearchShape(keyword: Self.sentinelKeyword), resultCount: .twoToFive)]
        )
    }

    // The single most important assertion in the phase's test suite. Reflect over the whole recorded
    // signal graph — every stored leaf, public or not — and prove the sentinel keyword survives
    // nowhere. A `SearchShape` carries only a word-count bucket, a tag-syntax flag and an exact length;
    // it cannot carry the keyword text (T-14-01).
    @MainActor
    @Test
    func theRecordedPerformedSignalCarriesNoPartOfTheKeyword() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeSearchStore(keyword: Self.sentinelKeyword, analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.fetchGalleriesDone(.failure(.notFound)))
        await store.skipInFlightEffects(strict: false)

        #expect(recorded.value.isEmpty == false)
        let leaves = Mirror(reflecting: recorded.value).leafRenderings
        #expect(leaves.contains(where: { $0.contains(Self.sentinelKeyword) }) == false)
    }

    // The emitted shape is reduced from the state's last-performed keyword: a three-word, one-word
    // namespace-qualified keyword exercises a multi-word count bucket, the tag-syntax flag, and the
    // exact grapheme length together, proving the reduction runs at the emission site rather than the
    // keyword being forwarded.
    @MainActor
    @Test
    func theRecordedPerformedSignalReflectsTheKeywordShape() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let keyword = "female:sole_female large breasts"
        let store = makeSearchStore(keyword: keyword, analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.fetchGalleriesDone(.failure(.notFound)))
        await store.skipInFlightEffects(strict: false)

        expectNoDifference(
            recorded.value,
            [.searchPerformed(shape: SearchShape(keyword: keyword), resultCount: .zero)]
        )
    }

    // MARK: History keyword (SearchRootReducer)

    // The persistence action that carries the raw keyword records nothing: only the reduced shape from
    // the fetch-completion case ever crosses the analytics boundary (T-14-01). Asserted with the same
    // sentinel so a regression that started forwarding the keyword here would be caught.
    @MainActor
    @Test
    func appendingAHistoryKeywordRecordsNoSignals() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeSearchRootStore(analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.appendHistoryKeyword(Self.sentinelKeyword))
        await store.skipInFlightEffects(strict: false)

        expectNoDifference(recorded.value, [])
        let leaves = Mirror(reflecting: recorded.value).leafRenderings
        #expect(leaves.contains(where: { $0.contains(Self.sentinelKeyword) }) == false)
    }

    // MARK: Filter and quick-search panels

    @MainActor
    @Test
    func openingTheSearchFilterPanelRecordsOneSignalNamingSearch() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeSearchStore(keyword: "", analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.filtersButtonTapped)
        await store.skipInFlightEffects(strict: false)

        expectNoDifference(recorded.value, [.filterPanelOpened(.search)])
    }

    @MainActor
    @Test
    func openingTheSearchQuickSearchPanelRecordsOneSignalNamingSearch() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeSearchStore(keyword: "", analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.quickSearchButtonTapped)
        await store.skipInFlightEffects(strict: false)

        expectNoDifference(recorded.value, [.quickSearchPanelOpened(.search)])
    }

    @MainActor
    @Test
    func openingTheSearchRootFilterPanelRecordsOneSignalNamingSearchRoot() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeSearchRootStore(analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.filtersButtonTapped)
        await store.skipInFlightEffects(strict: false)

        expectNoDifference(recorded.value, [.filterPanelOpened(.searchRoot)])
    }

    @MainActor
    @Test
    func openingTheSearchRootQuickSearchPanelRecordsOneSignalNamingSearchRoot() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeSearchRootStore(analyticsClient: .recording(into: recorded))
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.quickSearchButtonTapped)
        await store.skipInFlightEffects(strict: false)

        expectNoDifference(recorded.value, [.quickSearchPanelOpened(.searchRoot)])
    }

    // MARK: Quick-search word (QuickSearchReducer)

    // The word-usage signal is payload-free by construction: the word's name and content are forbidden
    // content, so nothing about it may be transmitted. The reflection assertion pins that a distinctive
    // fixture word survives nowhere in the recorded signal (T-14-01).
    @MainActor
    @Test
    func selectingAQuickSearchWordRecordsOnePayloadFreeSignal() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        await withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            let store = TestStore(initialState: .init(), reducer: QuickSearchReducer.init) {
                $0.analyticsClient = .recording(into: recorded)
                $0.defaultAppStorage = UserDefaults.inMemory
            }
            store.exhaustivity = .off(showSkippedAssertions: false)

            await store.send(.wordTapped)
            await store.skipInFlightEffects(strict: false)

            expectNoDifference(recorded.value, [.quickSearchWordUsed])
            let leaves = Mirror(reflecting: recorded.value).leafRenderings
            #expect(leaves.contains(where: { $0.contains(Self.sentinelWord) }) == false)
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
    static let sentinelKeyword = "SENTINEL_KEYWORD_must_never_leak"
    static let sentinelWord = "SENTINEL_WORD_must_never_leak"

    @MainActor
    func makeSearchStore(keyword: String, analyticsClient: AnalyticsClient) -> TestStoreOf<SearchReducer> {
        let appStorage = UserDefaults.inMemory

        return withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            TestStore(
                initialState: SearchReducer.State(keyword: keyword),
                reducer: SearchReducer.init,
                withDependencies: {
                    $0.analyticsClient = analyticsClient
                    $0.defaultAppStorage = appStorage
                    $0.downloadClient = .noop
                    $0.hapticsClient = .noop
                }
            )
        }
    }

    @MainActor
    func makeSearchRootStore(analyticsClient: AnalyticsClient) -> TestStoreOf<SearchRootReducer> {
        let appStorage = UserDefaults.inMemory

        return withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            TestStore(
                initialState: SearchRootReducer.State(),
                reducer: SearchRootReducer.init,
                withDependencies: {
                    $0.analyticsClient = analyticsClient
                    $0.defaultAppStorage = appStorage
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
