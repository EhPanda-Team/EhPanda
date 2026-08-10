import AnalyticsClient
@testable import AppFeature
import AppModels
import ComposableArchitecture
import DownloadClient
@testable import DownloadsFeature
import Foundation
import Testing

// `@MainActor` here is compiler-required, not stylistic: every case below builds a TCA
// `TestStore`, whose `init` and `state` accessor are main-actor-isolated. It is applied
// per member rather than to the suite so the type's `DownloadFeatureTestCase` conformance
// stays nonisolated — a main-actor conformance cannot be used from the `@Sendable`
// dependency closures these stores install.
struct DownloadInspectorRetryTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testDownloadInspectorKeepsRetriedPagesPendingWhileRetryWorkRemainsActive() async {
        let download = sampleDownload(
            gid: "112236", title: "Retry Pending Gallery",
            status: .partial, completedPageCount: 1
        )
        let refreshedInspection = sampleInspection(download: download)
        var initialState = DownloadInspectorReducer.State(gid: download.gid)
        initialState.inspection = sampleInspection(download: download)
        initialState.stableInspection = sampleInspection(download: download)
        initialState.retryingPageIndices = [2]
        initialState.loadingState = .idle

        let store = makeRetryTestStore(
            initialState: initialState,
            loadInspection: { _ in refreshedInspection }
        )
        store.exhaustivity = .off

        await store.send(.loadInspection)
        let requestID = store.state.inspectionRequestID
        await store.send(.loadInspectionDone(requestID, .success(refreshedInspection))) {
            $0.inspection = .init(
                download: download, coverURL: refreshedInspection.coverURL,
                pages: [
                    refreshedInspection.pages[0],
                    .init(
                        index: 2, status: .pending,
                        relativePath: "\(download.gid)_\(download.token)_2.jpg",
                        fileURL: nil, failure: nil
                    )
                ]
            )
            $0.loadingState = .idle
            $0.retryingPageIndices = [2]
        }
    }

    @MainActor
    @Test
    func testDownloadInspectorClearsRetryingPagesAfterRetrySettlesWithFailure() async {
        let initialDownload = sampleDownload(
            gid: "112237", title: "Retry Failure Gallery",
            status: .partial, completedPageCount: 1
        )
        let settledDownload = sampleDownload(
            gid: "112237", title: "Retry Failure Gallery", status: .partial,
            completedPageCount: 1, lastError: .init(code: .networkingFailed, message: "Network Error")
        )
        let settledInspection = sampleInspection(download: settledDownload)
        var initialState = DownloadInspectorReducer.State(gid: initialDownload.gid)
        initialState.inspection = sampleInspection(download: initialDownload)
        initialState.stableInspection = sampleInspection(download: initialDownload)
        initialState.retryingPageIndices = [2]
        initialState.loadingState = .idle

        let store = makeRetryTestStore(
            initialState: initialState,
            loadInspection: { _ in settledInspection }
        )
        store.exhaustivity = .off

        await store.send(.loadInspection)
        let requestID = store.state.inspectionRequestID
        await store.send(.loadInspectionDone(requestID, .success(settledInspection))) {
            $0.inspection = settledInspection
            $0.stableInspection = settledInspection
            $0.loadingState = .idle
            $0.retryingPageIndices = []
        }
    }

    @MainActor
    @Test
    func testDownloadInspectorRestoresStableInspectionWhenRetryReloadFails() async {
        let download = sampleDownload(
            gid: "112238", title: "Retry Reload Failure Gallery",
            status: .partial, completedPageCount: 1
        )
        let stableInspection = sampleInspection(download: download)
        var initialState = DownloadInspectorReducer.State(gid: download.gid)
        initialState.inspection = .init(
            download: download, coverURL: stableInspection.coverURL,
            pages: [
                stableInspection.pages[0],
                .init(
                    index: 2, status: .pending,
                    relativePath: "\(download.gid)_\(download.token)_2.jpg",
                    fileURL: nil, failure: nil
                )
            ]
        )
        initialState.stableInspection = stableInspection
        initialState.retryingPageIndices = [2]
        initialState.loadingState = .idle

        let store = makeRetryTestStore(
            initialState: initialState,
            loadInspection: { _ in throw AppError.networkingFailed }
        )
        store.exhaustivity = .off

        let requestID = store.state.inspectionRequestID
        await store.send(.loadInspectionDone(requestID, .failure(.networkingFailed))) {
            $0.inspection = stableInspection
            $0.loadingState = .failed(.networkingFailed)
            $0.retryingPageIndices = []
        }
    }

    /// The optimistic overlay may not contradict the badge beside it (D-SSOT-08).
    ///
    /// Under the widened retry basis the selection this action receives is the WHOLE page set for a
    /// record on the error surface with a file-shaped failure, and every page of such a record reads
    /// `.downloaded`. An overlay that rewrote each selected index unconditionally would therefore
    /// report "all pending, none downloaded" and drop every thumbnail, in the same List as a badge
    /// still counting them complete — and `retryPagesDone(.success)` returns `.none`, so nothing
    /// would correct the screen until the next `observeDownloadsDone` round trip.
    ///
    /// The selection here covers both a downloaded page and a failed one deliberately: asserting only
    /// that the downloaded page survives would also pass for an overlay that had stopped working, so
    /// the page the overlay IS for has to move in the same assertion.
    @MainActor
    @Test
    func testDownloadInspectorLeavesDownloadedPagesAloneWhenTheRetrySelectionCoversThem() async {
        let download = sampleDownload(
            gid: "112239", title: "Widened Retry Gallery",
            status: .partial, completedPageCount: 1
        )
        let inspection = sampleInspection(download: download)
        var initialState = DownloadInspectorReducer.State(gid: download.gid)
        initialState.inspection = inspection
        initialState.stableInspection = inspection
        initialState.loadingState = .idle

        let store = makeRetryTestStore(
            initialState: initialState,
            loadInspection: { _ in inspection }
        )
        store.exhaustivity = .off

        await store.send(.retryPages([1, 2])) {
            $0.retryingPageIndices = [1, 2]
            $0.inspection = .init(
                download: download,
                coverURL: inspection.coverURL,
                pages: [
                    // Untouched, thumbnail and all: the record says this page is done.
                    inspection.pages[0],
                    .init(
                        index: 2, status: .pending,
                        relativePath: "\(download.gid)_\(download.token)_2.jpg",
                        fileURL: nil, failure: nil
                    )
                ]
            )
        }
    }

    // MARK: The refusal has to reach the user (WR-04)

    /// A refused Retry tap is not a no-op, and the screen has to say so.
    ///
    /// The failure arm already cleared `retryingPageIndices` and reloaded the inspection, which
    /// resettles the list but reports nothing: the rows flash to `.pending` from the optimistic
    /// rewrite and then silently revert, indistinguishable from a network failure or from a tap
    /// that never registered. The reducer already owns a toast surface and already uses it to
    /// report a validation result, so this wires an existing affordance rather than inventing one.
    ///
    /// **The caption is the CLIENT's sentence, not one this screen picks.** Only the boundary knows
    /// which of its refusals happened, and the distinct error exists precisely so the message can
    /// match the condition. A caption chosen here would be the conflation WR-04 names, moved one
    /// layer up.
    @MainActor
    @Test
    func testDownloadInspectorSurfacesTheClientsMessageWhenARetryIsRefused() async {
        let refusalMessage = "The pages you selected are no longer part of this gallery."
        let download = sampleDownload(
            gid: "112240", title: "Refused Retry Gallery",
            status: .partial, completedPageCount: 1
        )
        let inspection = sampleInspection(download: download)
        var initialState = DownloadInspectorReducer.State(gid: download.gid)
        initialState.inspection = inspection
        initialState.stableInspection = inspection
        initialState.retryingPageIndices = [2]
        initialState.loadingState = .idle

        let store = makeRetryTestStore(
            initialState: initialState,
            loadInspection: { _ in inspection }
        )
        store.exhaustivity = .off

        await store.send(.retryPagesDone(.failure(.fileOperationFailed(refusalMessage)))) {
            $0.toast = .error(caption: refusalMessage)
            $0.retryingPageIndices = []
        }
        // The pre-existing half of the branch, re-pinned: surfacing the refusal must not replace the
        // resettle it already performed.
        await store.receive(\.loadInspection)
    }

    /// A failure that carries no message of its own still reports itself.
    ///
    /// `.notFound` remains the truthful answer for the two ABSENCE exits — the gallery is gone, or
    /// its folder is — and those are conditions the user is owed a word about too. The caption falls
    /// back to the error's own wording rather than to silence, so wiring the toast to one error kind
    /// alone would fail here.
    @MainActor
    @Test
    func testDownloadInspectorSurfacesAMessageForARetryFailureThatCarriesNoneOfItsOwn() async {
        let download = sampleDownload(
            gid: "112242", title: "Absent Retry Gallery",
            status: .partial, completedPageCount: 1
        )
        let inspection = sampleInspection(download: download)
        var initialState = DownloadInspectorReducer.State(gid: download.gid)
        initialState.inspection = inspection
        initialState.stableInspection = inspection
        initialState.retryingPageIndices = [2]
        initialState.loadingState = .idle

        let store = makeRetryTestStore(
            initialState: initialState,
            loadInspection: { _ in inspection }
        )
        store.exhaustivity = .off

        await store.send(.retryPagesDone(.failure(.notFound))) {
            $0.toast = .error(caption: AppError.notFound.alertText)
            $0.retryingPageIndices = []
        }
        await store.receive(\.loadInspection)
    }

    /// The boundary from the other side: accepted work is not an occasion for a toast.
    ///
    /// Passes pre-fix, deliberately. Its job is to keep the fix from buying visibility by reporting
    /// every outcome — a success toast on a tap whose only effect is that the queue accepted the
    /// work would be noise the user has to dismiss, and `retryPagesDone(.success)` returns `.none`
    /// precisely because the observe stream is what reports the queued work afterwards.
    @MainActor
    @Test
    func testDownloadInspectorSetsNoToastWhenARetryRequestIsAccepted() async {
        let download = sampleDownload(
            gid: "112243", title: "Accepted Retry Gallery",
            status: .partial, completedPageCount: 1
        )
        let inspection = sampleInspection(download: download)
        var initialState = DownloadInspectorReducer.State(gid: download.gid)
        initialState.inspection = inspection
        initialState.stableInspection = inspection
        initialState.retryingPageIndices = [2]
        initialState.loadingState = .idle

        let store = makeRetryTestStore(
            initialState: initialState,
            loadInspection: { _ in inspection }
        )
        store.exhaustivity = .off

        await store.send(.retryPagesDone(.success(())))
        #expect(store.state.toast == nil)
        #expect(store.state.retryingPageIndices == [2])
    }
}

// MARK: - Store Factory Helpers

private extension DownloadInspectorRetryTests {
    @MainActor
    func makeRetryTestStore(
        initialState: DownloadInspectorReducer.State,
        loadInspection: @escaping @Sendable (String) async throws -> DownloadInspection
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
                $0.downloadClient.togglePause = { _ in }
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.retryPages = { _, _ in }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
                $0.downloadClient.loadInspection = loadInspection
            }
        )
    }
}
