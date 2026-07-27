import AnalyticsClient
@testable import AppFeature
import AppModels
import ComposableArchitecture
import DeviceClient
import DownloadClient
@testable import DownloadsFeature
import Foundation
import Testing

// `@MainActor` here is compiler-required, not stylistic: the annotated cases build a TCA
// `TestStore`, whose `init` and `state` accessor are main-actor-isolated. The unannotated
// cases deliberately stay nonisolated so they keep running concurrently rather than being
// hopped onto the main actor by a suite-wide annotation.
struct DownloadsReducerActionTests: DownloadFeatureTestCase {
    @MainActor
    @Test
    func testDownloadsReducerKeepsIdleStateForEmptyLibrary() async {
        let store = TestStore(initialState: DownloadsReducer.State(), reducer: DownloadsReducer.init) {
            $0.analyticsClient = .noop
        }

        await store.send(.fetchDownloadsDone([])) {
            $0.loadingState = .idle
        }

        #expect(store.state.downloads == [])
    }

    @MainActor
    @Test
    func testDownloadsReducerSeedsOnlineDetailStateFromDownload() async {
        let download = sampleDownload(
            gid: "123456",
            title: "Completed Gallery",
            status: .completed
        )
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(
            initialState: initialState,
            reducer: DownloadsReducer.init,
            withDependencies: {
                $0.analyticsClient = .noop
                $0.deviceClient = .noop
                // The pushed detail now starts its own load on presentation, so its dependencies
                // have to be stubbed even though this test only asserts the push itself.
                $0.downloadClient = .noop
                $0.cookieClient = .noop
                $0.hapticsClient = .noop
                $0.date = .constant(.init(timeIntervalSince1970: 0))
            }
        )
        store.exhaustivity = .off

        await store.send(.galleryTapped(download.gid))
        await store.receive(\.pushGalleryDetail)

        #expect(store.state.path.count == 1)
        guard let element = store.state.path.first, case .detail(let detailState) = element else {
            Issue.record("Expected a pushed detail element")
            return
        }
        #expect(detailState.gid == download.gid)
        #expect(detailState.gallery.id == download.gid)
        #expect(detailState.downloadBadge?.status == .completed)
        #expect(detailState.shouldCheckForRemoteUpdates == true)
    }

    @MainActor
    @Test
    func testDownloadsReducerDoubleTapPushesDetailOnce() async {
        let download = sampleDownload(
            gid: "123456",
            title: "Completed Gallery",
            status: .completed
        )
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(
            initialState: initialState,
            reducer: DownloadsReducer.init,
            withDependencies: {
                $0.analyticsClient = .noop
                $0.deviceClient = .noop
                // The pushed detail now starts its own load on presentation, so its dependencies
                // have to be stubbed even though this test only asserts the push itself.
                $0.downloadClient = .noop
                $0.cookieClient = .noop
                $0.hapticsClient = .noop
                $0.date = .constant(.init(timeIntervalSince1970: 0))
            }
        )
        store.exhaustivity = .off

        await store.send(.galleryTapped(download.gid))
        await store.receive(\.pushGalleryDetail)
        #expect(store.state.path.count == 1)

        // A rapid second activation must not push a duplicate adjacent detail.
        await store.send(.galleryTapped(download.gid))
        await store.receive(\.pushGalleryDetail)
        #expect(store.state.path.count == 1)
    }

    @MainActor
    @Test
    func testDownloadsReducerDelegatesModalDetailOnPad() async {
        let download = sampleDownload(
            gid: "123456",
            title: "Completed Gallery",
            status: .completed
        )
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(
            initialState: initialState,
            reducer: DownloadsReducer.init,
            withDependencies: {
                $0.analyticsClient = .noop
                $0.deviceClient = DeviceClient(
                    deviceType: { .pad },
                    isLandscape: { false },
                    interfaceOrientation: { .portrait }
                )
            }
        )
        store.exhaustivity = .off

        await store.send(.galleryTapped(download.gid))
        await store.receive(\.delegate)

        // The host must not push inline on iPad; AppReducer presents the modal instead.
        #expect(store.state.path.isEmpty)
    }

    @Test
    func testDownloadsReducerFolderFilterNarrowsDownloads() async {
        let libraryDownload = sampleDownload(
            gid: "111", title: "Library Archive", status: .completed, folderName: "Library"
        )
        let otherDownload = sampleDownload(
            gid: "222", title: "Other Archive", status: .completed, folderName: "Other"
        )
        var state = DownloadsReducer.State()
        state.downloads = [libraryDownload, otherDownload]

        state.folderFilter = .all
        #expect(state.filteredDownloads == [libraryDownload, otherDownload])

        state.folderFilter = .folder("Library")
        #expect(state.filteredDownloads == [libraryDownload])

        state.folderFilter = .folder("Vanished")
        #expect(state.filteredDownloads.isEmpty)
    }

    @MainActor
    @Test
    func testDownloadsReducerPrunesStaleFolderFilterAfterFetch() async {
        var initialState = DownloadsReducer.State()
        initialState.folderFilter = .folder("Vanished")

        let store = TestStore(initialState: initialState, reducer: DownloadsReducer.init) {
            $0.analyticsClient = .noop
        }

        await store.send(.fetchFoldersDone(["Library"])) {
            $0.folders = ["Library"]
            $0.folderFilter = .all
        }

        await store.send(.fetchFoldersDone(["Library", "Other"])) {
            $0.folders = ["Library", "Other"]
        }
    }

    @MainActor
    @Test
    func testDownloadsReducerMoveActionUsesDownloadClientMove() async {
        let moved = UncheckedBox<(gid: String, folder: String)?>(nil)
        let store = TestStore(
            initialState: DownloadsReducer.State(),
            reducer: DownloadsReducer.init,
            withDependencies: {
                $0.analyticsClient = .noop
                $0.downloadClient = DownloadClient()
                $0.downloadClient.observeDownloads = {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
                $0.downloadClient.fetchDownloads = { [] }
                $0.downloadClient.fetchDownload = { _ in nil }
                $0.downloadClient.refreshDownloads = {}
                $0.downloadClient.enqueue = { _ in }
                $0.downloadClient.togglePause = { _ in }
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
                $0.downloadClient.fetchFolders = { ["Library"] }
                $0.downloadClient.moveDownload = { gid, folder in
                    moved.value = (gid, folder)
                }
            }
        )
        store.exhaustivity = .off

        await store.send(.moveDownload(gid: "123456", folderName: "Library"))
        await store.receive(\.moveDownloadDone)
        await store.receive(\.fetchFoldersDone) {
            $0.folders = ["Library"]
        }

        #expect(moved.value?.gid == "123456")
        #expect(moved.value?.folder == "Library")
    }

    @MainActor
    @Test
    func testDownloadsReducerUpdateActionUsesDownloadClientRetry() async {
        let retried = UncheckedBox<[String]>([])
        let download = sampleDownload(
            gid: "123456",
            title: "Completed Gallery",
            status: .updateAvailable
        )
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(
            initialState: initialState,
            reducer: DownloadsReducer.init,
            withDependencies: {
                $0.analyticsClient = .noop
                $0.downloadClient = DownloadClient()
                $0.downloadClient.observeDownloads = {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
                $0.downloadClient.fetchDownloads = { [] }
                $0.downloadClient.fetchDownload = { _ in nil }
                $0.downloadClient.refreshDownloads = {}
                $0.downloadClient.enqueue = { _ in }
                $0.downloadClient.togglePause = { _ in }
                $0.downloadClient.retry = { gid, mode in
                    if mode == .update {
                        retried.value.append(gid)
                    }
                }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
            }
        )
        store.exhaustivity = .off

        await store.send(.updateDownload(download.gid))
        await store.receive(\.updateDownloadDone)

        #expect(retried.value == [download.gid])
    }

    @MainActor
    @Test
    func testDownloadsReducerDeleteActionUsesDownloadClientDelete() async {
        let deleted = UncheckedBox<[String]>([])
        let download = sampleDownload(
            gid: "654321",
            title: "Completed Gallery",
            status: .completed
        )
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(
            initialState: initialState,
            reducer: DownloadsReducer.init,
            withDependencies: {
                $0.analyticsClient = .noop
                $0.downloadClient = DownloadClient()
                $0.downloadClient.observeDownloads = {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
                $0.downloadClient.fetchDownloads = { [] }
                $0.downloadClient.fetchDownload = { _ in nil }
                $0.downloadClient.refreshDownloads = {}
                $0.downloadClient.enqueue = { _ in }
                $0.downloadClient.togglePause = { _ in }
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.delete = { gid in
                    deleted.value.append(gid)
                }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
            }
        )
        store.exhaustivity = .off

        await store.send(.deleteDownload(download.gid))
        await store.receive(\.deleteDownloadDone)

        #expect(deleted.value == [download.gid])
    }

    @MainActor
    @Test
    func testDownloadsReducerOpenReadingLoadsManifestAndRoutesToReader() async throws {
        let download = sampleDownload(
            gid: "135790",
            title: "Readable Gallery",
            status: .completed,
            pageCount: 2
        )
        let manifest = try sampleManifest(
            gid: download.gid,
            title: download.title,
            pageCount: 2
        )
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(
            initialState: initialState,
            reducer: DownloadsReducer.init,
            withDependencies: {
                $0.analyticsClient = .noop
                // The reader's session tracking reads the date dependency on presentation (14-14).
                $0.date = .constant(Date(timeIntervalSince1970: 0))
                $0.downloadClient = DownloadClient()
                $0.downloadClient.observeDownloads = {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
                $0.downloadClient.fetchDownloads = { [] }
                $0.downloadClient.fetchDownload = { _ in nil }
                $0.downloadClient.refreshDownloads = {}
                $0.downloadClient.enqueue = { _ in }
                $0.downloadClient.togglePause = { _ in }
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { gid in
                    guard gid == download.gid else { throw AppError.notFound }
                    return (download, manifest)
                }
                // A completed download has its pages on disk; the reader's presentation load falls
                // back to `.remote` when it finds none.
                $0.downloadClient.loadLocalPageURLs = { gid in
                    guard gid == download.gid else { return [:] }
                    return manifest.pages.keys.reduce(into: [Int: URL]()) { urls, page in
                        urls[page] = download.folderURL.appending(path: "\(page).jpg")
                    }
                }
            }
        )
        store.exhaustivity = .off

        await store.send(.openReading(download.gid))
        await store.receive(\.openReadingDone)
        await store.skipReceivedActions(strict: false)

        #expect(store.state.destination?.reading?.contentSource == .local(download: download, manifest: manifest))
    }

    @MainActor
    @Test
    func testDownloadsReducerTogglePauseActionUsesDownloadClientPause() async {
        let toggled = UncheckedBox<[String]>([])
        let download = sampleDownload(
            gid: "987654",
            title: "Downloading Gallery",
            status: .downloading,
            completedPageCount: 9
        )
        var initialState = DownloadsReducer.State()
        initialState.downloads = [download]

        let store = TestStore(
            initialState: initialState,
            reducer: DownloadsReducer.init,
            withDependencies: {
                $0.analyticsClient = .noop
                $0.downloadClient = DownloadClient()
                $0.downloadClient.observeDownloads = {
                    AsyncStream { continuation in
                        continuation.finish()
                    }
                }
                $0.downloadClient.fetchDownloads = { [] }
                $0.downloadClient.fetchDownload = { _ in nil }
                $0.downloadClient.refreshDownloads = {}
                $0.downloadClient.enqueue = { _ in }
                $0.downloadClient.togglePause = { gid in
                    toggled.value.append(gid)
                }
                $0.downloadClient.retry = { _, _ in }
                $0.downloadClient.delete = { _ in }
                $0.downloadClient.loadManifest = { _ in throw AppError.notFound }
            }
        )
        store.exhaustivity = .off

        await store.send(.toggleDownloadPause(download.gid))
        await store.receive(\.toggleDownloadPauseDone)

        #expect(toggled.value == [download.gid])
    }

}
