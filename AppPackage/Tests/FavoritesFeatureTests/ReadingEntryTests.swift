import AnalyticsClient
import AppLaunchAutomationClient
import AppModels
import ComposableArchitecture
import CookieClient
import DownloadClient
@testable import FavoritesFeature
import Foundation
import HapticsClient
import ReadingFeature
import Testing

@MainActor
struct ReadingEntryTests {
    @Test
    func singleTapOnlyDelegatesToDetail() async {
        let store = makeStore()
        await store.send(.galleryTapped(.preview))
        await store.receive(\.delegate.openGalleryDetail, .preview)
        #expect(store.state.destination == nil)
    }

    @Test
    func aMissingLocalAndRemoteSourceReportsFailureWithoutOpeningDetail() async {
        let store = makeStore()
        store.exhaustivity = .off
        await store.send(.openReading(.preview))
        await store.receive(\.openReadingDone)
        #expect(store.state.readingRequestID == nil)
        #expect(store.state.toast != nil)
        #expect(store.state.path.isEmpty)
        #expect(store.state.destination == nil)
        await store.finish()
    }

    @Test
    func aLaterDetailTapRejectsAPendingReadingResponse() async {
        let requestID = UUID()
        let store = makeStore(readingRequestID: requestID)
        store.exhaustivity = .off
        await store.send(.galleryTapped(.preview))
        await store.receive(\.delegate.openGalleryDetail)
        await store.send(.openReadingDone(requestID: requestID, .success(.init(gallery: .preview))))
        #expect(store.state.destination == nil)
        await store.finish()
    }

    @Test
    func localReadingUsesManifestAndClosesBackToFavorites() async {
        let manifest = DownloadManifest(
            gid: "12345", host: .ehentai, token: "token", title: "Local reading", jpnTitle: nil,
            category: .manga, language: .english, remoteCoverURL: nil, uploader: nil, tags: [],
            postedDate: .distantPast, rating: 0, pages: [1: "hash", 2: "hash"]
        )
        let download = DownloadedGallery(
            manifest: manifest, folderURL: URL(filePath: "/tmp/library-reading-test"), folderName: "Test",
            localCoverURL: nil, localPageURLs: [:], modificationDate: nil, displayStatus: .completed
        )
        let store = makeStore(download: download)
        store.exhaustivity = .off
        await store.send(.openReading(.preview))
        await store.receive(\.openReadingDone)
        await store.receive(\.destination.presented.reading.onPresented)
        #expect(store.state.destination?.reading?.gallery.id == manifest.gid)
        #expect(store.state.destination?.reading?.language == .english)
        #expect(store.state.destination?.reading?.contentSource == .local(download: download, manifest: manifest))
        #expect(store.state.path.isEmpty)
        await store.send(.destination(.presented(.reading(.onPerformDismiss))))
        await store.receive(\.destination.dismiss)
        #expect(store.state.destination == nil)
        await store.finish()
    }

    private func makeStore(
        download: DownloadedGallery? = nil, readingRequestID: UUID? = nil
    ) -> TestStoreOf<FavoritesReducer> {
        let appStorage = UserDefaults.inMemory
        return withDependencies {
            $0.defaultAppStorage = appStorage
        } operation: {
            var state = FavoritesReducer.State()
            state.readingRequestID = readingRequestID
            return TestStore(initialState: state, reducer: FavoritesReducer.init) {
                $0.defaultAppStorage = appStorage
                $0.analyticsClient = .noop
                $0.appLaunchAutomationClient = .none
                $0.date = .constant(.distantPast)
                $0.cookieClient = .noop
                $0.downloadClient = .noop
                $0.downloadClient.loadManifest = { _ in
                    guard let download else { throw AppError.notFound }
                    return (download, download.manifest)
                }
                $0.hapticsClient = .noop
            }
        }
    }
}
