import AnalyticsClient
import AppComponents
@testable import AppFeature
import AppModels
import ComposableArchitecture
import DownloadClient
@testable import DownloadsFeature
import Foundation
import Testing
import TestingSupport

/// A queue operation in the downloads LIST reports a refusal and stays silent on success (DES-3).
///
/// The sibling of `DownloadsPauseFailureTests` for `performQueueOperation`: the tap sends the gid and the
/// operation to the client unchanged, an accepted request sets no toast (the row's new place arrives through
/// `observeDownloads`), and a refused one (`.notFound` for a record deleted underneath the row, `.unknown` for a
/// status or place that no longer allows it) shows the shared action-failure toast.
@Suite(.isolatedAppStorage)
struct DownloadsQueueOperationReducerTests: DownloadFeatureTestCase {
    private struct QueueOperationCall: Equatable, Sendable {
        let gid: String
        let operation: DownloadQueueOperation
    }

    @MainActor
    @Test(arguments: DownloadQueueOperation.allCases)
    func testAnAcceptedQueueOperationIsSentAndSetsNoToast(_ operation: DownloadQueueOperation) async {
        let calls = LockedBox([QueueOperationCall]())
        let store = makeQueueOperationTestStore(
            download: sampleDownload(gid: "113260", title: "Queue Operation Gallery", status: .queued),
            performQueueOperation: { gid, operation in
                calls.value.append(QueueOperationCall(gid: gid, operation: operation))
            }
        )

        await store.send(.performQueueOperation(gid: "113260", operation: operation))
        await store.receive(\.performQueueOperationDone)

        #expect(store.state.toast == nil)
        #expect(calls.value == [QueueOperationCall(gid: "113260", operation: operation)])
    }

    @MainActor
    @Test(arguments: DownloadQueueOperation.allCases)
    func testARefusedQueueOperationShowsTheActionFailureToast(_ operation: DownloadQueueOperation) async {
        let store = makeQueueOperationTestStore(
            download: sampleDownload(gid: "113260", title: "Queue Operation Gallery", status: .queued),
            performQueueOperation: { _, _ in throw AppError.unknown }
        )

        await store.send(.performQueueOperation(gid: "113260", operation: operation))
        await store.receive(\.performQueueOperationDone) {
            $0.toast = .error(caption: AppError.unknown.alertText)
        }
    }

    @MainActor
    @Test
    func testAQueueOperationOnAVanishedGalleryShowsNotFound() async {
        let store = makeQueueOperationTestStore(
            download: sampleDownload(gid: "113260", title: "Queue Operation Gallery", status: .queued)
        )

        await store.send(.performQueueOperationDone(.failure(.notFound))) {
            $0.toast = .error(caption: AppError.notFound.alertText)
        }
    }
}

// MARK: - Fixture Helpers

private extension DownloadsQueueOperationReducerTests {
    @MainActor
    func makeQueueOperationTestStore(
        download: DownloadedGallery,
        performQueueOperation: @escaping @Sendable (String, DownloadQueueOperation) async throws -> Void = { _, _ in }
    ) -> TestStoreOf<DownloadsReducer> {
        var initialState = DownloadsReducer.State()
        initialState.loadingState = .idle
        initialState.downloads = [download]

        return TestStore(
            initialState: initialState,
            reducer: DownloadsReducer.init,
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
                $0.downloadClient.performQueueOperation = performQueueOperation
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.retryPages = { _, _ in }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
            }
        )
    }
}
