import AnalyticsClient
import AppModels
import ComposableArchitecture
@testable import DetailFeature
import DownloadClient
import Foundation
import Testing

// Exact-sequence proof for DetailFeature's six emission sites: the tag tap, the three download
// outcomes, and the detail-search screen's two panels. Each case drives its reducer through a store
// whose analytics client is a `LockIsolated`-backed spy and asserts the recorded sequence, not
// merely that something was recorded.
//
// Two groups of assertions here are load-bearing beyond the emissions themselves:
//
//   - The tag-tap case asserts the recorded signal *and* the forwarded keyword in one test. This
//     plan widened a view callback to carry the namespace; splitting the two assertions would let a
//     later change keep the signal passing while breaking the search the tap is supposed to perform
//     (T-14-16).
//   - Five cases assert an *empty* recorded sequence. Those encode boundaries that are otherwise
//     only comments: download failure belongs to the downloads-list transition diff, the tag-detail
//     sheet is not a search, and pause/resume is outside the signal vocabulary entirely.
//
// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
@Suite
struct AnalyticsEmissionTests {

    // MARK: Tag taps

    // The namespace reaches the signal and the keyword reaches the delegate, asserted together. The
    // sweep covers every recognized namespace plus the unrecognized (`nil`) case, so a namespace
    // added to `TagNamespace` later arrives here as a new argument rather than as silence.
    @MainActor
    @Test(arguments: Self.everyNamespaceAndNil)
    func tagSearchTapRecordsTheNamespaceAndForwardsTheKeyword(namespace: TagNamespace?) async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDetailStore(analyticsClient: .recording(into: recorded))

        await store.send(.tagSearchTapped(keyword: Self.sentinelKeyword, namespace: namespace))
        await store.receive(\.delegate, .pushDetailSearch(Self.sentinelKeyword))
        await store.finish()

        expectNoDifference(recorded.value, [.tagTapped(namespace: namespace)])
    }

    // Reflect over the whole recorded signal graph and prove the sentinel keyword survives nowhere.
    // The signal carries a closed namespace enum and nothing else, so the tag text it was assembled
    // from is structurally unable to follow — this pins that (T-14-01).
    @MainActor
    @Test
    func tagTapSignalCarriesNoPartOfTheKeyword() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDetailStore(analyticsClient: .recording(into: recorded))

        await store.send(.tagSearchTapped(keyword: Self.sentinelKeyword, namespace: .female))
        await store.receive(\.delegate, .pushDetailSearch(Self.sentinelKeyword))
        await store.finish()

        #expect(recorded.value.isEmpty == false)
        let leaves = Mirror(reflecting: recorded.value).leafRenderings
        #expect(leaves.contains(where: { $0.contains(Self.sentinelKeyword) }) == false)
    }

    // The tag-detail sheet is informational, not a search, and `TagDetail` carries no namespace to
    // emit. Asserted rather than assumed so a later contributor does not add one for symmetry.
    @MainActor
    @Test
    func tagDetailButtonTappedRecordsNothing() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDetailStore(analyticsClient: .recording(into: recorded))

        await store.send(.tagDetailButtonTapped(
            TagDetail(title: "Title", description: "Description", imageURLs: [], links: [])
        ))
        await store.finish()

        #expect(recorded.value.isEmpty)
    }

    // MARK: Download outcomes — success arms

    @MainActor
    @Test
    func startDownloadSuccessRecordsStarted() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDetailStore(analyticsClient: .recording(into: recorded))

        await store.send(.startDownloadDone(.success(())))
        await store.finish()

        expectNoDifference(recorded.value, [.downloadStateChanged(.started)])
    }

    @MainActor
    @Test
    func retryDownloadSuccessRecordsRetried() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDetailStore(analyticsClient: .recording(into: recorded))

        await store.send(.retryDownloadDone(.success(())))
        await store.finish()

        expectNoDifference(recorded.value, [.downloadStateChanged(.retried)])
    }

    @MainActor
    @Test
    func deleteDownloadSuccessRecordsDeleted() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDetailStore(analyticsClient: .recording(into: recorded))

        await store.send(.deleteDownloadDone(.success(())))
        await store.finish()

        expectNoDifference(recorded.value, [.downloadStateChanged(.deleted)])
    }

    // MARK: Download outcomes — failure arms stay silent
    //
    // The `failed` outcome is owned by the downloads-list transition diff, which observes a download
    // failing during transfer. These three assertions are the enforcement of that ownership split:
    // without them, "we decided failure belongs to the other module" is a comment a refactor can
    // quietly contradict.

    @MainActor
    @Test
    func startDownloadFailureRecordsNothing() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDetailStore(analyticsClient: .recording(into: recorded))

        await store.send(.startDownloadDone(.failure(.notFound)))
        await store.finish()

        #expect(recorded.value.isEmpty)
    }

    @MainActor
    @Test
    func retryDownloadFailureRecordsNothing() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDetailStore(analyticsClient: .recording(into: recorded))

        await store.send(.retryDownloadDone(.failure(.notFound)))
        await store.finish()

        #expect(recorded.value.isEmpty)
    }

    @MainActor
    @Test
    func deleteDownloadFailureRecordsNothing() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDetailStore(analyticsClient: .recording(into: recorded))

        await store.send(.deleteDownloadDone(.failure(.notFound)))
        await store.finish()

        #expect(recorded.value.isEmpty)
    }

    // The retry button serves two intents, told apart by the pre-mutation badge status: a gallery
    // flagged `.updateAvailable` is being *updated* and must report `.updated`, the same name the
    // downloads list emits for the same action — one intent, one name (D-21). This replaces the
    // original assertion that the badge status did not matter.
    @MainActor
    @Test
    func retryFromUpdateAvailableRecordsUpdatedNotRetried() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDetailStore(
            analyticsClient: .recording(into: recorded),
            badgeStatus: .updateAvailable
        )

        await store.send(.retryDownloadDone(.success(())))
        await store.finish()

        expectNoDifference(recorded.value, [.downloadStateChanged(.updated)])
    }

    // MARK: Pause and resume (D-20)
    //
    // One toggle action serves both directions; the pre-mutation badge status is what tells them
    // apart. This replaced the zero-signal test that pinned the pre-D-20 exclusion — that test
    // failing on D-20's arrival was it working as intended.

    @MainActor
    @Test(arguments: [
        (badge: DownloadDisplayStatus.active, outcome: DownloadOutcome.paused),
        (badge: DownloadDisplayStatus.inactive, outcome: DownloadOutcome.resumed)
    ])
    func togglePauseSuccessRecordsTheDirection(
        badge: DownloadDisplayStatus,
        outcome: DownloadOutcome
    ) async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDetailStore(analyticsClient: .recording(into: recorded), badgeStatus: badge)

        await store.send(.toggleDownloadPauseDone(.success(())))
        await store.finish()

        expectNoDifference(recorded.value, [.downloadStateChanged(outcome)])
    }

    // A toggle from any other badge status is not a user-meaningful pause or resume; guessing a
    // direction would be worse than silence. The failure arm is silent like every other outcome.
    @MainActor
    @Test
    func togglePauseWithoutADirectionOrOnFailureRecordsNothing() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDetailStore(analyticsClient: .recording(into: recorded))

        await store.send(.toggleDownloadPauseDone(.success(())))
        await store.send(.toggleDownloadPauseDone(.failure(.notFound)))
        await store.finish()

        #expect(recorded.value.isEmpty)
    }

    // MARK: Detail-search panels

    @MainActor
    @Test
    func openingTheFilterPanelRecordsDetailSearch() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDetailSearchStore(analyticsClient: .recording(into: recorded))

        await store.send(.filtersButtonTapped)
        await store.finish()

        expectNoDifference(recorded.value, [.filterPanelOpened(.detailSearch)])
    }

    @MainActor
    @Test
    func openingTheQuickSearchPanelRecordsDetailSearch() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDetailSearchStore(analyticsClient: .recording(into: recorded))

        await store.send(.quickSearchButtonTapped)
        await store.finish()

        expectNoDifference(recorded.value, [.quickSearchPanelOpened(.detailSearch)])
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
    static let sentinelKeyword = "SENTINEL_KEYWORD_must_never_leak"

    // Every recognized namespace, plus `nil` for a tag whose scraped namespace is unrecognized. The
    // sweep is derived from `allCases` rather than listed, so it cannot fall behind the enum.
    static let everyNamespaceAndNil: [TagNamespace?] = TagNamespace.allCases.map({ $0 }) + [nil]

    @MainActor
    func makeDetailStore(
        analyticsClient: AnalyticsClient,
        badgeStatus: DownloadDisplayStatus? = nil
    ) -> TestStoreOf<DetailReducer> {
        var state = DetailReducer.State(
            gallery: Gallery(
                gid: "42", token: "abc123", title: "Seed", rating: 4.5, tags: [],
                category: .doujinshi, pageCount: 30, postedDate: .init(timeIntervalSince1970: 0),
                coverURL: nil, galleryURL: URL(string: "https://example.com/g/42/abc123/")
            )
        )
        state.galleryDetail = .preview
        if let badgeStatus {
            state.downloadBadge = DownloadBadge(
                status: badgeStatus,
                progress: DownloadProgress(completedPageCount: 0, pageCount: 30)
            )
        }

        let store = TestStore(initialState: state, reducer: DetailReducer.init) {
            $0.analyticsClient = analyticsClient
            $0.downloadClient = .noop
            $0.hapticsClient = .noop
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
    }

    @MainActor
    func makeDetailSearchStore(analyticsClient: AnalyticsClient) -> TestStoreOf<DetailSearchReducer> {
        let store = TestStore(
            initialState: DetailSearchReducer.State(keyword: "seed"),
            reducer: DetailSearchReducer.init
        ) {
            $0.analyticsClient = analyticsClient
            $0.hapticsClient = .noop
        }
        store.exhaustivity = .off(showSkippedAssertions: false)
        return store
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
