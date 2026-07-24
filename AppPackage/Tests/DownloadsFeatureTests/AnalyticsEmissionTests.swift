import AnalyticsClient
import AppModels
import AppTools
import ComposableArchitecture
@testable import DownloadsFeature
import Foundation
import Testing

// Two layers of proof for this module's five emission sites.
//
// The downloads list learns about progress through a stream of **full snapshots**, not events, so the
// naive instrumentation reports one finished download again on every observation tick and reports the
// entire library as freshly completed at every cold start. `outcomeTransitions` is a pure function of
// two snapshots precisely so those edge semantics can be covered exhaustively and cheaply here,
// without a store; the store-level cases then prove the helper is actually wired at the right point
// in the case — before the incoming snapshot overwrites the previous one.
//
// The cold-start case is the single most important assertion in this file: getting it wrong produces
// a phantom completion burst proportional to how much the user has downloaded.
//
// @MainActor sits on store-driving members only. The pure-helper cases need no actor and are
// deliberately left free to run off the main actor.
@Suite
struct AnalyticsEmissionTests: DownloadFeatureTestCase {

    // MARK: Layer 1 — the pure transition diff

    // Cold start: the previous snapshot is empty because the app just launched. Every download in it
    // is already finished, and none of them completed *now*.
    @Test
    func anEmptyPreviousSnapshotEmitsNothing() {
        let outcomes = DownloadsReducer.outcomeTransitions(
            from: [],
            to: [Self.download(gid: "1", status: .completed)]
        )

        expectNoDifference(outcomes, [])
    }

    @Test
    func aDownloadReachingCompletedEmitsOneCompletedOutcome() {
        let outcomes = DownloadsReducer.outcomeTransitions(
            from: [Self.download(gid: "1", status: .downloading)],
            to: [Self.download(gid: "1", status: .completed)]
        )

        expectNoDifference(outcomes, [.completed])
    }

    @Test
    func aDownloadReachingErrorEmitsOneFailedOutcome() {
        let outcomes = DownloadsReducer.outcomeTransitions(
            from: [Self.download(gid: "1", status: .downloading)],
            to: [Self.download(gid: "1", status: .failed)]
        )

        expectNoDifference(outcomes, [.failed])
    }

    // The tick-repetition case. A status that has not changed is not an event, however many snapshots
    // report it.
    @Test
    func anUnchangedCompletedStatusEmitsNothingHoweverManySnapshotsArrive() {
        let finished = [Self.download(gid: "1", status: .completed)]

        for _ in 1...5 {
            expectNoDifference(DownloadsReducer.outcomeTransitions(from: finished, to: finished), [])
        }
    }

    @Test
    func intermediateStatusChangesEmitNothing() {
        let outcomes = DownloadsReducer.outcomeTransitions(
            from: [Self.download(gid: "1", status: .queued)],
            to: [Self.download(gid: "1", status: .downloading)]
        )

        expectNoDifference(outcomes, [])
    }

    // Two galleries transitioning in one snapshot emit one signal each, ordered by the incoming
    // snapshot so the sequence is deterministic rather than dictionary-ordered.
    @Test
    func twoTransitionsInOneSnapshotEmitTwoOutcomesInOrder() {
        let outcomes = DownloadsReducer.outcomeTransitions(
            from: [
                Self.download(gid: "1", status: .downloading),
                Self.download(gid: "2", status: .downloading)
            ],
            to: [
                Self.download(gid: "1", status: .completed),
                Self.download(gid: "2", status: .failed)
            ]
        )

        expectNoDifference(outcomes, [.completed, .failed])
    }

    // A gallery leaving the snapshot is a deletion, owned by the explicit delete action.
    @Test
    func aDownloadDisappearingFromTheSnapshotEmitsNothing() {
        let outcomes = DownloadsReducer.outcomeTransitions(
            from: [Self.download(gid: "1", status: .downloading)],
            to: []
        )

        expectNoDifference(outcomes, [])
    }

    // MARK: Layer 2 — wired into the reducer

    // Proves the diff is taken *before* the state assignment. If it were taken after, the previous
    // and incoming snapshots would be identical and this would record nothing.
    @MainActor
    @Test
    func repeatedIdenticalFinishedSnapshotsRecordExactlyOneSignal() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDownloadsStore(recorded: recorded)
        let active = [Self.download(gid: "1", status: .downloading)]
        let finished = [Self.download(gid: "1", status: .completed)]

        await store.send(.observeDownloadsDone(active))
        for _ in 1...3 { await store.send(.observeDownloadsDone(finished)) }
        await store.skipInFlightEffects(strict: false)

        expectNoDifference(recorded.value, [.downloadStateChanged(.completed)])
    }

    // The cold-start path through the store: the first snapshot the reducer ever sees.
    @MainActor
    @Test
    func theFirstSnapshotAfterLaunchRecordsNothing() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDownloadsStore(recorded: recorded)

        await store.send(.observeDownloadsDone([
            Self.download(gid: "1", status: .completed),
            Self.download(gid: "2", status: .completed)
        ]))
        await store.skipInFlightEffects(strict: false)

        #expect(recorded.value.isEmpty)
    }

    @MainActor
    @Test
    func deleteSuccessRecordsDeletedAndFailureRecordsNothing() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDownloadsStore(recorded: recorded)

        await store.send(.deleteDownloadDone(.success(())))
        await store.skipInFlightEffects(strict: false)
        expectNoDifference(recorded.value, [.downloadStateChanged(.deleted)])

        recorded.setValue([])
        await store.send(.deleteDownloadDone(.failure(.notFound)))
        await store.skipInFlightEffects(strict: false)
        #expect(recorded.value.isEmpty)
    }

    @MainActor
    @Test
    func moveSuccessRecordsMovedAndFailureRecordsNothing() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDownloadsStore(recorded: recorded)

        await store.send(.moveDownloadDone(.success(())))
        await store.skipInFlightEffects(strict: false)
        expectNoDifference(recorded.value, [.downloadStateChanged(.moved)])

        recorded.setValue([])
        await store.send(.moveDownloadDone(.failure(.notFound)))
        await store.skipInFlightEffects(strict: false)
        #expect(recorded.value.isEmpty)
    }

    @MainActor
    @Test
    func pushingAGalleryDetailRecordsOneSignalMatchingTheFixture() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDownloadsStore(recorded: recorded)
        let fixture = Self.sentinelDownload()
        let expected = TagNamespaceCounts(tags: fixture.gallery.tags)

        await store.send(.pushGalleryDetail(fixture))
        await store.skipInFlightEffects(strict: false)

        expectNoDifference(
            recorded.value,
            [.galleryDetailOpened(category: fixture.gallery.category, tagNamespaces: expected)]
        )
    }

    // Reflect over the whole recorded signal graph and prove the fixture's distinctive title, tag text
    // and folder name survive nowhere (T-14-01).
    @MainActor
    @Test
    func pushedGalleryDetailSignalCarriesNoFixtureContent() async {
        let recorded = LockIsolated<[AnalyticsSignal]>([])
        let store = makeDownloadsStore(recorded: recorded)

        await store.send(.pushGalleryDetail(Self.sentinelDownload()))
        await store.skipInFlightEffects(strict: false)

        #expect(recorded.value.isEmpty == false)
        let leaves = Mirror(reflecting: recorded.value).leafRenderings
        #expect(leaves.contains(where: { $0.contains(Self.sentinelTitle) }) == false)
        #expect(leaves.contains(where: { $0.contains(Self.sentinelTagText) }) == false)
        #expect(leaves.contains(where: { $0.contains(Self.sentinelFolderName) }) == false)
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
    static let sentinelFolderName = "SENTINEL_FOLDER_must_never_leak"

    // Reuses this target's `sampleDownload` factory, so the status fixtures stay consistent with the
    // rest of the suite rather than introducing a parallel notion of a downloaded gallery.
    static func download(gid: String, status: DownloadFixtureStatus) -> DownloadedGallery {
        AnalyticsEmissionTests().sampleDownload(gid: gid, title: "Download \(gid)", status: status)
    }

    // The factory hardcodes empty tags and a plain folder name, so the leak fixture is built directly:
    // the reflection assertion needs distinctive tokens in exactly those fields. Two recognized
    // namespaces with known counts (female: 2, artist: 1) keep the emitted counts predictable.
    static func sentinelDownload() -> DownloadedGallery {
        DownloadedGallery(
            gid: "9001",
            host: .ehentai,
            token: "sentinel-token",
            title: sentinelTitle,
            jpnTitle: nil,
            uploader: "Uploader",
            category: .manga,
            tags: [
                GalleryTag(rawNamespace: "female", contents: [
                    tagContent(namespace: "female", text: sentinelTagText + "-a"),
                    tagContent(namespace: "female", text: sentinelTagText + "-b")
                ]),
                GalleryTag(rawNamespace: "artist", contents: [
                    tagContent(namespace: "artist", text: sentinelTagText + "-c")
                ])
            ],
            pageCount: 10,
            postedDate: Date(timeIntervalSince1970: 0),
            rating: 4,
            onlineCoverURL: nil,
            folderURL: FileUtil.downloadsDirectoryURL
                .appendingPathComponent(sentinelFolderName, isDirectory: true),
            folderName: sentinelFolderName,
            localCoverURL: nil,
            localPageURLs: [:],
            displayStatus: .completed,
            completedPageCount: 10,
            lastDownloadedDate: Date(timeIntervalSince1970: 0),
            lastError: nil
        )
    }

    static func tagContent(namespace: String, text: String) -> GalleryTag.Content {
        GalleryTag.Content(rawNamespace: namespace, text: text, isVotedUp: false, isVotedDown: false)
    }

    @MainActor
    func makeDownloadsStore(recorded: LockIsolated<[AnalyticsSignal]>) -> TestStoreOf<DownloadsReducer> {
        let store = TestStore(initialState: DownloadsReducer.State(), reducer: DownloadsReducer.init) {
            $0.analyticsClient = .recording(into: recorded)
            // The gallery-detail push seeds a DetailFeature screen, which reads the date dependency.
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0.downloadClient = .noop
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
