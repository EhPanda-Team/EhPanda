import AnalyticsClient
import AppLaunchAutomationClient
import AppModels
import ComposableArchitecture
@testable import DetailFeature
import DownloadClient
import Foundation
import GalleryClient
import HapticsClient
import NetworkingFeature
import ReadingFeature
import Testing
import TestingSupport

/// The reader a gallery list opens directly (D89, D146): its source, its failure and its late results.
@Suite(.isolatedAppStorage)
@MainActor
struct GalleryReadingFeatureTests {
    private let gallery = Gallery(
        gid: "12345", token: "token", title: "List reading", rating: 0, tags: [],
        category: .manga, uploader: "", pageCount: 2, postedDate: .distantPast,
        coverURL: nil, galleryURL: URL(string: "https://e-hentai.org/g/12345/token/")
    )

    @Test
    func aDownloadedGalleryReadsItsManifestAndDismissesBackToTheList() async {
        let download = DownloadedGallery(
            manifest: DownloadManifest(
                gid: gallery.gid, host: .ehentai, token: gallery.token, title: gallery.title, jpnTitle: nil,
                category: .manga, language: .english, remoteCoverURL: nil, uploader: nil, tags: [],
                postedDate: .distantPast, rating: 0, pages: [1: "hash", 2: "hash"]
            ),
            folderURL: URL(filePath: "/tmp/gallery-reading-test"), folderName: "Test",
            localCoverURL: nil, localPageURLs: [:], modificationDate: nil, displayStatus: .completed
        )
        let store = makeStore {
            $0.downloadClient.loadManifest = { _ in (download, download.manifest) }
        }
        store.exhaustivity = .off
        await store.send(.open(gallery))
        await store.receive(\.openDone)
        await store.receive(\.reader.presented.onPresented)
        #expect(store.state.reader?.contentSource == .local(download: download, manifest: download.manifest))
        #expect(store.state.reader?.language == .english)
        await store.send(.reader(.presented(.onPerformDismiss)))
        await store.receive(\.reader.dismiss)
        #expect(store.state.reader == nil)
        await store.finish()
    }

    @Test
    func aRemoteGalleryReadsTheFetchedPreviewConfiguration() async {
        let previewURL = URL(string: "https://e-hentai.org/s/preview/12345-1")
        let galleryState = GalleryState(
            gid: gallery.gid, previewURLs: [1: previewURL].compactMapValues(\.self), previewConfig: .large(rows: 2)
        )
        let response = GalleryDetailResponse(galleryDetail: .preview, galleryState: galleryState, apiKey: "")
        let store = makeStore {
            $0.galleryClient.fetchGalleryDetail = { _, _ in response }
        }
        store.exhaustivity = .off
        await store.send(.open(gallery))
        await store.receive(\.openDone)
        #expect(store.state.reader?.previewConfig == .large(rows: 2))
        #expect(store.state.reader?.language == GalleryDetail.preview.language)
        #expect(store.state.reader?.previewURLs == galleryState.previewURLs)
        await store.send(.reader(.dismiss))
        await store.finish()
    }

    @Test
    func aFailedOpenShowsAToastAndNoReader() async {
        let store = makeStore()
        store.exhaustivity = .off
        await store.send(.open(gallery)) {
            $0.requestID = UUID(0)
        }
        await store.receive(\.openDone)
        #expect(!store.state.isOpening)
        #expect(store.state.toast != nil)
        #expect(store.state.reader == nil)
        await store.finish()
    }

    @Test
    func aCancelledOpenDropsItsLateResult() async {
        var state = GalleryReadingFeature.State()
        state.requestID = UUID(0)
        state.cancelOpening()
        let store = makeStore(state)
        await store.send(.openDone(requestID: UUID(0), .success(.init(gallery: gallery))))
        await store.send(.openDone(requestID: UUID(0), .failure(.notFound)))
    }

    @Test
    func flushActionTargetsOnlyAPresentedReader() {
        var state = GalleryReadingFeature.State()
        #expect(state.flushAction == nil)
        state.reader = ReadingReducer.State(gallery: gallery)
        #expect(state.flushAction?.is(\.reader) == true)
    }

    @Test
    func aDetailSearchReaderIsFlushedThroughTheGalleryPath() {
        var detailSearch = DetailSearchReducer.State(keyword: "fixture")
        #expect(GalleryPath.State.detailSearch(detailSearch).readingFlushAction == nil)
        detailSearch.reading.reader = ReadingReducer.State(gallery: gallery)
        let action = GalleryPath.State.detailSearch(detailSearch).readingFlushAction
        #expect(action?[case: \.detailSearch.reading.reader.presented.flushReadingProgress] != nil)
    }

    private func makeStore(
        _ state: GalleryReadingFeature.State = .init(),
        dependencies: @escaping (inout DependencyValues) -> Void = { _ in }
    ) -> TestStoreOf<GalleryReadingFeature> {
        TestStore(initialState: state, reducer: GalleryReadingFeature.init) {
            // A presented reader reads the launch's capture route and stamps its session with the date.
            $0.analyticsClient = .noop
            $0.appLaunchAutomationClient = .none
            $0.date = .constant(Date(timeIntervalSince1970: 0))
            $0.downloadClient = .noop
            $0.galleryClient = .noop
            $0.hapticsClient = .noop
            $0.uuid = .incrementing
            dependencies(&$0)
        }
    }
}
