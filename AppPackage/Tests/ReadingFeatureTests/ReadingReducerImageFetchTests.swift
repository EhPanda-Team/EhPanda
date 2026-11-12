import AnalyticsClient
import AppLaunchAutomationClient
import AppModels
import ComposableArchitecture
import CookieClient
import DownloadClient
import Foundation
import HapticsClient
@testable import ReadingFeature
import Sharing
import Testing

// @MainActor sits on members, never on this type: TCA's `TestStore.init` and `.state` are
// main-actor-isolated, so every store-driving case needs it. Annotating the type instead would
// make the suite's protocol conformances main-actor-isolated too (see 11-22-SUMMARY.md).
// Any case left unannotated is deliberately free to run off the main actor.
struct ReadingReducerImageFetchTests {
    @MainActor
    @Test
    func refetchResponseWritesSkipServerToOriginatingHost() async throws {
        let cookieClient = CookieClient.testing()
        let response = try #require(HTTPURLResponse(
            url: GalleryHost.ehentai.url,
            statusCode: 200,
            httpVersion: "HTTP/1.1",
            headerFields: ["Set-Cookie": "skipserver=origin-server; Path=/s/; Secure"]
        ))
        let inMemoryStorage = InMemoryStorage()
        let store = withDependencies {
            $0.defaultInMemoryStorage = inMemoryStorage
        } operation: {
            @Shared(.setting) var setting
            $setting.withLock({ $0.galleryHost = .ehentai })
            let state = ReadingReducer.State(gallery: .preview)
            $setting.withLock({ $0.galleryHost = .exhentai })
            return TestStore(
                initialState: state,
                reducer: ReadingReducer.init,
                withDependencies: {
                    $0.analyticsClient = .noop
                    $0.cookieClient = cookieClient
                    $0.defaultInMemoryStorage = inMemoryStorage
                }
            )
        }

        await store.send(
            .refetchNormalImageURLsDone(
                index: 1, host: .ehentai, result: .success((imageURLs: [:], response: response))
            )
        ) {
            $0.imageURLLoadingStates[1] = .failed(.notFound)
        }
        await store.finish()

        let ehentaiSkipServerURL = GalleryHost.ehentai.url.appending(path: "s/")
        let exhentaiSkipServerURL = GalleryHost.exhentai.url.appending(path: "s/")
        #expect(skipServerValue(in: cookieClient, url: ehentaiSkipServerURL) == "origin-server")
        #expect(skipServerValue(in: cookieClient, url: exhentaiSkipServerURL) == nil)
    }

    // MARK: Opening at a page loads that page

    // A reader opened on a preview, or resumed, starts at a non-zero position that is applied
    // programmatically. No page cell appears for that, so the reducer has to start the first fetch
    // itself when the reader is presented.
    @MainActor
    @Test
    func presentingAtASavedPageFetchesThatPageAndMarksItsBatchLoading() async {
        let store = makeStore(savedProgress: 5)
        // Past the asserted actions the requests answer at any moment (the test network guard fails them).
        store.exhaustivity = .off(showSkippedAssertions: false)
        let batch = store.state.previewConfig.batchRange(index: 5)
        #expect(store.state.position.displayedPage == 5)

        await store.send(.onPresented) {
            $0.sessionStartDate = Self.now
            $0.visitedPages = [5]
        }
        await store.receive(\.observeDownloads)
        await store.receive(\.loadLocalPageURLs)
        await store.receive(\.fetchImageURLs, 5)
        await store.receive(\.prefetchImages)
        await store.receive(\.fetchThumbnailURLs, 5) {
            for page in batch { $0.imageURLLoadingStates[page] = .loading }
        }
        await store.skipInFlightEffects(strict: false)
    }

    @MainActor
    @Test
    func presentingAtTheFirstPageFetchesTheFirstPage() async {
        let store = makeStore(savedProgress: 1)
        store.exhaustivity = .off(showSkippedAssertions: false)
        let batch = store.state.previewConfig.batchRange(index: 1)

        await store.send(.onPresented) {
            $0.sessionStartDate = Self.now
            $0.visitedPages = [1]
        }
        await store.receive(\.observeDownloads)
        await store.receive(\.loadLocalPageURLs)
        await store.receive(\.fetchImageURLs, 1)
        await store.receive(\.fetchThumbnailURLs, 1) {
            for page in batch { $0.imageURLLoadingStates[page] = .loading }
        }
        await store.skipInFlightEffects(strict: false)
    }

    @MainActor
    @Test
    func presentingWithoutSavedProgressFetchesTheFirstPage() async {
        let store = makeStore(savedProgress: nil)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onPresented) {
            $0.sessionStartDate = Self.now
            $0.visitedPages = [1]
        }
        await store.receive(\.observeDownloads)
        await store.receive(\.loadLocalPageURLs)
        await store.receive(\.fetchImageURLs, 1)
        await store.receive(\.fetchThumbnailURLs, 1)
        await store.skipInFlightEffects(strict: false)
    }

    // The page's own `.onAppear` asks again once the cell is built. With the batch loading, that
    // must not start a second request: `fetchThumbnailURLs` drops it and no response is awaited.
    @MainActor
    @Test
    func fetchingAPageWhoseBatchIsLoadingStartsNoNewRequest() async {
        var state = makeStore(savedProgress: 5).state
        for page in state.previewConfig.batchRange(index: 5) {
            state.imageURLLoadingStates[page] = .loading
        }
        let store = makeStore(initialState: state)

        await store.send(.fetchImageURLs(5))
        await store.receive(\.fetchThumbnailURLs, 5)
        // Exhaustive: a request in flight would deliver a response nobody asserted, or never finish.
        await store.finish()
    }

    // The keys of a multi-page-viewer gallery arrive after the reader's one fetch of the opening page, which
    // could only resolve the thumbnail batch. The keys' own follow-up fetched only the first three pages, so a
    // reader opened on page 12 showed nothing until the cell asked again.
    @MainActor
    @Test
    func theMPVKeysAlsoFetchThePageTheReaderShows() async {
        let store = makeStore(savedProgress: 12)
        let batch = store.state.previewConfig.batchRange(index: 12)
        let keys = Dictionary(uniqueKeysWithValues: (1...30).map { ($0, "key\($0)") })
        let imageList = MPVImageList(key: "mpv", imageKeys: keys, originalSizes: [:])
        var state = store.state
        for page in batch { state.imageURLLoadingStates[page] = .loading }
        let loadingStore = makeStore(initialState: state)
        loadingStore.exhaustivity = .off(showSkippedAssertions: false)

        await loadingStore.send(.fetchMPVKeysDone(index: 12, result: .success(imageList))) {
            $0.mpvKey = "mpv"
            $0.mpvImageKeys = keys
            for page in batch { $0.imageURLLoadingStates[page] = .idle }
        }
        for page in [1, 2, 3, 12] {
            await loadingStore.receive(\.fetchMPVImageURL) {
                $0.imageURLLoadingStates[page] = .loading
            }
        }
        await loadingStore.skipInFlightEffects(strict: false)
    }

    // An offline reader reads local files only. Presenting it must start no network fetch, so no page
    // is marked loading.
    @MainActor
    @Test
    func presentingAReaderWhoseFirstPageIsLocalStartsNoNetworkFetch() async {
        var state = makeStore(savedProgress: 5).state
        let file = URL(filePath: "/tmp/\(UUID().uuidString).jpg")
        state.localPageURLs = [5: file]
        let store = makeStore(initialState: state)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.onPresented) {
            $0.sessionStartDate = Self.now
            $0.visitedPages = [5]
        }
        await store.receive(\.observeDownloads)
        await store.receive(\.loadLocalPageURLs)
        await store.receive(\.fetchImageURLs, 5) {
            $0.imageURLLoadingStates[5] = .idle
        }
        await store.receive(\.prefetchImages)
        await store.skipInFlightEffects(strict: false)

        #expect(!store.state.imageURLLoadingStates.values.contains(.loading))
    }
}

private extension ReadingReducerImageFetchTests {
    static let now = Date(timeIntervalSince1970: 1_000)

    static let gallery = Gallery(
        gid: "42", token: "abc123", title: "Resume", rating: 4.5, tags: [],
        category: .doujinshi, pageCount: 30, postedDate: .init(timeIntervalSince1970: 0),
        coverURL: nil, galleryURL: URL(string: "https://example.com/g/42/abc123/")
    )

    /// A store on a remote 30-page gallery whose saved reading progress is `savedProgress`.
    @MainActor
    func makeStore(savedProgress: Int?) -> TestStoreOf<ReadingReducer> {
        let inMemoryStorage = InMemoryStorage()
        return withDependencies {
            $0.defaultInMemoryStorage = inMemoryStorage
        } operation: {
            if let savedProgress {
                @Shared(.galleryHistory) var history
                $history.withLock {
                    $0.recordGalleryOpen(gid: Self.gallery.id, token: Self.gallery.token, date: Self.now)
                    $0.updateReadingProgress(
                        gid: Self.gallery.id, token: Self.gallery.token, progress: savedProgress, date: Self.now
                    )
                }
            }
            return makeStore(initialState: ReadingReducer.State(gallery: Self.gallery), storage: inMemoryStorage)
        }
    }

    @MainActor
    func makeStore(
        initialState: ReadingReducer.State, storage: InMemoryStorage = InMemoryStorage()
    ) -> TestStoreOf<ReadingReducer> {
        withDependencies {
            $0.defaultInMemoryStorage = storage
        } operation: {
            TestStore(
                initialState: initialState,
                reducer: ReadingReducer.init,
                withDependencies: {
                    $0.analyticsClient = .noop
                    $0.appLaunchAutomationClient = .none
                    $0.continuousClock = TestClock()
                    $0.cookieClient = .noop
                    $0.date = .constant(Self.now)
                    $0.defaultInMemoryStorage = storage
                    $0.downloadClient = .noop
                    $0.hapticsClient = .noop
                }
            )
        }
    }
}

private func skipServerValue(in client: CookieClient, url: URL) -> String? {
    client.cookies(for: url).first { $0.name == "skipserver" }?.value
}
