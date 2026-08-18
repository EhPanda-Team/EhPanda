import AnalyticsClient
@testable import AppFeature
import AppModels
import ComposableArchitecture
import DownloadClient
@testable import DownloadsFeature
import Foundation
import Testing

/// The reload gate, which is the second half of G-15-2F.
///
/// `observeDownloadsDone` reloads the sheet only when the observed row DIFFERS from the one already
/// on screen, and that gate is what kept the stale reading up: a repair of a wholesale-refusal
/// record re-downloads pages whose hashes are byte-identical to the ones it already recorded, so
/// every published row was `==` its predecessor and no flush ever reached `.loadInspection`. Now the
/// live run's measurement rides on the row (D-SSOT-10), so the row really does differ at every
/// landing — and this suite pins that a difference in that field alone is enough to reload, with the
/// no-difference control beside it so the gate itself is not quietly widened to "always reload".
///
/// `@MainActor` here is compiler-required, not stylistic: both cases build a TCA `TestStore`, whose
/// `init` and `state` accessor are main-actor-isolated. It is applied per member rather than to the
/// suite so the type's `DownloadFeatureTestCase` conformance stays nonisolated — a main-actor
/// conformance cannot be used from the `@Sendable` dependency closures these stores install.
struct DownloadInspectorRunProgressReloadTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testARowThatDiffersOnlyInRunProgressReloadsTheInspection() async {
        let download = sampleDownload(
            gid: "260818-2F-reload",
            title: "Refusal Repair",
            status: .downloading,
            pageCount: 6,
            completedPageCount: 6
        )
        let inspection = sampleInspection(download: download)
        // Identical in every field the record supplies — same manifest, same hashes, same status —
        // and differing only in the run's own measurement, which is the exact shape a refusal
        // repair's flush publishes.
        let changed = download.carrying(
            runProgress: .init(creditedPageIndices: [1, 2])
        )
        let store = makeInspectorStore(
            gid: download.gid,
            initialInspection: inspection,
            loadInspection: { _ in inspection }
        )
        store.exhaustivity = .off

        await store.send(.observeDownloadsDone([changed]))
        await store.receive(\.loadInspection)
    }

    /// The control, asserted exhaustively: an identical row still reloads nothing, so the gate is
    /// narrowed by the new field rather than removed.
    @MainActor
    @Test
    func testAnIdenticalRowStillReloadsNothing() async {
        let download = sampleDownload(
            gid: "260818-2F-control",
            title: "Refusal Repair",
            status: .downloading,
            pageCount: 6,
            completedPageCount: 6
        )
        let inspection = sampleInspection(download: download)
        let store = makeInspectorStore(
            gid: download.gid,
            initialInspection: inspection,
            loadInspection: { _ in inspection }
        )

        await store.send(.observeDownloadsDone([download]))
        await store.finish()
    }
}

// MARK: - Setup Helpers

private extension DownloadedGallery {
    /// The same record with a run's measurement attached, built through the memberwise init so a
    /// field added later cannot be silently dropped from the copy.
    func carrying(runProgress: DownloadRunProgress) -> DownloadedGallery {
        DownloadedGallery(
            manifest: manifest,
            folderURL: folderURL,
            folderName: folderName,
            localCoverURL: localCoverURL,
            localPageURLs: localPageURLs,
            modificationDate: lastDownloadedDate,
            displayStatus: displayStatus,
            lastError: lastError,
            runProgress: runProgress
        )
    }
}

private extension DownloadInspectorRunProgressReloadTests {
    @MainActor
    func makeInspectorStore(
        gid: String,
        initialInspection: DownloadInspection,
        loadInspection: @escaping @Sendable (String) async throws -> DownloadInspection
    ) -> TestStoreOf<DownloadInspectorReducer> {
        var initialState = DownloadInspectorReducer.State(gid: gid)
        initialState.inspection = initialInspection
        initialState.loadingState = .idle
        return TestStore(
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
                $0.downloadClient.validateImageData = { _ in nil }
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
