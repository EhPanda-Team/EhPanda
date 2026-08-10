import AnalyticsClient
@testable import AppFeature
import AppModels
import ComposableArchitecture
import DownloadClient
@testable import DownloadsFeature
import Foundation
import Testing

/// A refused Pause/Resume tap in the inspector is not a no-op, and the screen has to say so (WR-05).
///
/// This is the sibling branch of the retry refusal `DownloadInspectorRetryTests` covers: the pause
/// branch sits 25 lines below it in the same reducer and reloads without reporting, so the row
/// reverts to the status the record still holds and nothing distinguishes a refusal from a tap that
/// never registered.
///
/// **The staged failure kinds are the ones `togglePause` actually answers.** Reading
/// `DownloadCoordinator.togglePause` (`DownloadClient+PublicAPI.swift:189-215`) and everything it
/// tail-calls — `pause` → `commitPause`, `resume`, `cancelQueuedWorkItem` — the reachable failures
/// are exactly two: `.notFound` when the record is gone (the `fetchDownload` guards at
/// `+PublicAPI.swift:190-192`, `+Scheduling.swift:236` and `+Scheduling.swift:356-358`), and
/// `.unknown` when the status moved out of the toggleable set between the render and the tap
/// (`+PublicAPI.swift:212-213`). Every other exit on those paths returns `.success`. Both render
/// through the mapping's `alertText` arm, so the payload arm is pinned separately and labelled as
/// what it is — a rename guard on a mapping this branch now shares with retry, not a claim that
/// `togglePause` can answer `.fileOperationFailed`.
///
/// `@MainActor` here is compiler-required, not stylistic: every case below builds a TCA `TestStore`,
/// whose `init` and `state` accessor are main-actor-isolated. It is applied per member rather than
/// to the suite so the type's `DownloadFeatureTestCase` conformance stays nonisolated — a
/// main-actor conformance cannot be used from the `@Sendable` dependency closures these stores
/// install.
struct DownloadInspectorPauseFailureTests: DownloadFeatureTestCase {
    /// The gallery was deleted underneath the inspector, and the user is owed that word.
    ///
    /// `.notFound` is `togglePause`'s answer for a gid its own `fetchDownload` can no longer
    /// resolve. Pre-fix this arm writes nothing at all — the branch is a bare
    /// `if case .failure = result { return .send(.loadInspection) }`, so the reload below is the
    /// ONLY observable, and the assertion fails precisely on the toast this case exists for.
    @MainActor
    @Test
    func testDownloadInspectorReportsAPauseRefusedBecauseTheGalleryVanished() async {
        let download = sampleDownload(
            gid: "112250", title: "Vanished Pause Gallery",
            status: .downloading, completedPageCount: 1
        )
        let inspection = sampleInspection(download: download)
        let store = makePauseTestStore(
            initialState: makeInspectorState(download: download, inspection: inspection),
            loadInspection: { _ in inspection }
        )
        store.exhaustivity = .off

        await store.send(.toggleDownloadPauseDone(.failure(.notFound))) {
            $0.toast = .error(caption: AppError.notFound.alertText)
        }
        // The pre-existing half of the branch, re-pinned: reporting the refusal must not replace the
        // resettle it already performed.
        await store.receive(\.loadInspection)
    }

    /// The status moved out of the toggleable set between the render and the tap.
    ///
    /// `canTogglePause` is evaluated against the snapshot the row was drawn from, so a gallery that
    /// completed, failed, or gained an update while the screen sat there still offers the control;
    /// the boundary refuses it with `.unknown` (`+PublicAPI.swift:212-213`). Without a toast the row
    /// simply snaps back on the reload, which reads as a dropped tap.
    @MainActor
    @Test
    func testDownloadInspectorReportsAPauseRefusedBecauseTheStatusMovedOn() async {
        let download = sampleDownload(
            gid: "112251", title: "Moved On Pause Gallery",
            status: .downloading, completedPageCount: 1
        )
        let inspection = sampleInspection(download: download)
        let store = makePauseTestStore(
            initialState: makeInspectorState(download: download, inspection: inspection),
            loadInspection: { _ in inspection }
        )
        store.exhaustivity = .off

        await store.send(.toggleDownloadPauseDone(.failure(.unknown))) {
            $0.toast = .error(caption: AppError.unknown.alertText)
        }
        await store.receive(\.loadInspection)
    }

    /// The mapping's payload arm, pinned through THIS branch as a rename guard.
    ///
    /// `.fileOperationFailed` is not a kind `togglePause` answers — the enumeration in this suite's
    /// header is exhaustive over its exits. The case is here because the pause branch now shares one
    /// private mapping with the retry branch, and that mapping has two arms: a payload-only
    /// rendering for `.fileOperationFailed` (whose payload already names which refusal happened, and
    /// which `alertText` would bury under its own generic "local file operation failed" line) and an
    /// `alertText` fallback for everything else. Renaming the mapping for its second consumer could
    /// silently drop either arm, so both are asserted from the pause side too. It also states the
    /// contract for the day `togglePause` grows a file-shaped refusal: the payload is what shows.
    @MainActor
    @Test
    func testDownloadInspectorRendersAPauseFailurePayloadWithoutTheGenericPrefix() async {
        let refusalMessage = "The download folder for this gallery is no longer readable."
        let download = sampleDownload(
            gid: "112252", title: "Payload Pause Gallery",
            status: .downloading, completedPageCount: 1
        )
        let inspection = sampleInspection(download: download)
        let store = makePauseTestStore(
            initialState: makeInspectorState(download: download, inspection: inspection),
            loadInspection: { _ in inspection }
        )
        store.exhaustivity = .off

        await store.send(.toggleDownloadPauseDone(.failure(.fileOperationFailed(refusalMessage)))) {
            $0.toast = .error(caption: refusalMessage)
        }
        await store.receive(\.loadInspection)
        // Keeps the case from being vacuous: the two arms really do render differently, so the
        // assertion above would fail if the payload arm were dropped in favour of the fallback.
        #expect(AppError.fileOperationFailed(refusalMessage).alertText != refusalMessage)
    }

    /// The whole tap path, not just the action: the effect's catch arm has to carry the kind.
    ///
    /// The two cases above drive `toggleDownloadPauseDone` directly, which would still pass if the
    /// effect swallowed the client's error or flattened every refusal into one kind. Here the
    /// dependency throws the boundary's own `.unknown` and the assertion reads the message the user
    /// would see, so the client seam — `AppError(error)` inside the `catch:` at
    /// `DownloadInspectorReducer.swift:217-219` — is covered end to end for this family, as
    /// `DownloadInspectorRetryTests` covers it for retry.
    @MainActor
    @Test
    func testDownloadInspectorReportsARefusalRaisedOnTheTapPath() async {
        let download = sampleDownload(
            gid: "112253", title: "Tap Path Pause Gallery",
            status: .downloading, completedPageCount: 1
        )
        let inspection = sampleInspection(download: download)
        let store = makePauseTestStore(
            initialState: makeInspectorState(download: download, inspection: inspection),
            loadInspection: { _ in inspection },
            togglePause: { _ in throw AppError.unknown }
        )
        store.exhaustivity = .off

        await store.send(.toggleDownloadPause)
        await store.receive(\.toggleDownloadPauseDone) {
            $0.toast = .error(caption: AppError.unknown.alertText)
        }
        await store.receive(\.loadInspection)
    }

    /// The boundary from the other side: an accepted toggle is not an occasion for a toast.
    ///
    /// Passes pre-fix, deliberately — its job is to keep the fix from buying visibility by reporting
    /// every outcome. A success toast on a tap whose only effect is that the queue accepted the
    /// change would be noise the user has to dismiss, and the branch returns `.none` precisely
    /// because the observe stream reports the new status afterwards.
    ///
    /// This case keeps FULL exhaustivity on purpose: with it, an added `.send(.loadInspection)` on
    /// the success arm fails the case as an unreceived action, so "no toast AND no reload" is pinned
    /// rather than only the first half.
    @MainActor
    @Test
    func testDownloadInspectorSetsNoToastWhenAPauseRequestIsAccepted() async {
        let download = sampleDownload(
            gid: "112254", title: "Accepted Pause Gallery",
            status: .downloading, completedPageCount: 1
        )
        let inspection = sampleInspection(download: download)
        let store = makePauseTestStore(
            initialState: makeInspectorState(download: download, inspection: inspection),
            loadInspection: { _ in inspection }
        )

        await store.send(.toggleDownloadPauseDone(.success(())))
        #expect(store.state.toast == nil)
    }
}

// MARK: - Fixture Helpers

private extension DownloadInspectorPauseFailureTests {
    func makeInspectorState(
        download: DownloadedGallery,
        inspection: DownloadInspection
    ) -> DownloadInspectorReducer.State {
        var state = DownloadInspectorReducer.State(gid: download.gid)
        state.inspection = inspection
        state.stableInspection = inspection
        state.loadingState = .idle
        return state
    }

    @MainActor
    func makePauseTestStore(
        initialState: DownloadInspectorReducer.State,
        loadInspection: @escaping @Sendable (String) async throws -> DownloadInspection,
        togglePause: @escaping @Sendable (String) async throws -> Void = { _ in }
    ) -> TestStoreOf<DownloadInspectorReducer> {
        TestStore(
            initialState: initialState,
            reducer: DownloadInspectorReducer.init,
            withDependencies: {
                $0.analyticsClient = .noop
                $0.downloadClient = DownloadClient()
                $0.downloadClient.observeDownloads = {
                    AsyncStream { continuation in continuation.finish() }
                }
                $0.downloadClient.fetchDownloads = { [] }
                $0.downloadClient.fetchDownload = { _ in nil }
                $0.downloadClient.refreshDownloads = {}
                $0.downloadClient.enqueue = { _ in }
                $0.downloadClient.togglePause = togglePause
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.retryPages = { _, _ in }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
                $0.downloadClient.loadInspection = loadInspection
            }
        )
    }
}
