import AnalyticsClient
import AppLaunchAutomationClient
import AppModels
import ComposableArchitecture
import CookieClient
import DetailFeature
import DownloadClient
@testable import FavoritesFeature
import Foundation
import HapticsClient
import ReadingFeature
import Testing
import TestingSupport

/// Favorites hosts the shared list reader (`GalleryReadingFeature`, whose own behavior is covered in
/// DetailFeatureTests). These cases pin the host's side: which route a tap takes, and that a route the
/// user takes while a reader is being opened wins over the late result.
@Suite(.isolatedAppStorage)
@MainActor
struct ReadingEntryTests {
    @Test
    func singleTapOnlyDelegatesToDetail() async {
        let store = makeStore()
        await store.send(.galleryTapped(.preview))
        await store.receive(\.delegate.openGalleryDetail, .preview)
        #expect(store.state.reading.reader == nil)
    }

    @Test
    func aLaterDetailTapRejectsAPendingReadingResponse() async {
        await assertPendingOpenIsDropped { await $0.send(.galleryTapped(.preview)) }
    }

    @Test
    func aCategorySwitchRejectsAPendingReadingResponse() async {
        await assertPendingOpenIsDropped { await $0.send(.setFavoritesIndex(1)) }
    }

    @Test
    func readingADownloadedFavoriteOpensNoDetail() async {
        let store = makeStore(download: .fixture)
        store.exhaustivity = .off
        await store.send(.reading(.open(.preview)))
        await store.receive(\.reading.openDone)
        #expect(store.state.reading.reader?.contentSource == .local(
            download: .fixture, manifest: DownloadedGallery.fixture.manifest
        ))
        #expect(store.state.path.isEmpty)
        await store.send(.reading(.reader(.presented(.onPerformDismiss))))
        await store.receive(\.reading.reader.dismiss)
        #expect(store.state.reading.reader == nil)
        await store.finish()
    }

    /// Opens a reader whose source stays unresolved until `route` has run, then resolves it.
    private func assertPendingOpenIsDropped(
        after route: (TestStoreOf<FavoritesReducer>) async -> Void
    ) async {
        let gate = AsyncStream.makeStream(of: Void.self)
        let store = makeStore(download: .fixture, manifestGate: gate.stream)
        store.exhaustivity = .off
        await store.send(.reading(.open(.preview)))
        #expect(store.state.reading.isOpening)
        await route(store)
        #expect(!store.state.reading.isOpening)
        gate.continuation.yield()
        await store.receive(\.reading.openDone)
        #expect(store.state.reading.reader == nil)
        await store.finish()
    }

    private func makeStore(
        download: DownloadedGallery? = nil, manifestGate: AsyncStream<Void>? = nil
    ) -> TestStoreOf<FavoritesReducer> {
        TestStore(initialState: FavoritesReducer.State(), reducer: FavoritesReducer.init) {
            $0.analyticsClient = .noop
            $0.appLaunchAutomationClient = .none
            $0.date = .constant(.distantPast)
            $0.cookieClient = .noop
            $0.downloadClient = .noop
            $0.downloadClient.loadManifest = { _ in
                if let manifestGate {
                    for await _ in manifestGate { break }
                }
                guard let download else { throw AppError.notFound }
                return (download, download.manifest)
            }
            $0.hapticsClient = .noop
            $0.uuid = .incrementing
        }
    }
}

private extension DownloadedGallery {
    static let fixture = DownloadedGallery(
        manifest: DownloadManifest(
            gid: "12345", host: .ehentai, token: "token", title: "Local reading", jpnTitle: nil,
            category: .manga, language: .english, remoteCoverURL: nil, uploader: nil, tags: [],
            postedDate: .distantPast, rating: 0, pages: [1: "hash", 2: "hash"]
        ),
        folderURL: URL(filePath: "/tmp/library-reading-test"), folderName: "Test",
        localCoverURL: nil, localPageURLs: [:], modificationDate: nil, displayStatus: .completed
    )
}
