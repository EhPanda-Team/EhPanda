import AnalyticsClient
import AppComponents
import AppLaunchAutomationClient
import AppModels
import ComposableArchitecture
import CookieClient
import DownloadClient
import Foundation
import HapticsClient
@testable import ReadingFeature
import ReadingSettingFeature
import Sharing
import Testing
import TestingSupport

// Quick 261122-317 (D-01 to D-07): with "always read webtoons vertically" on, the reader decides once, from the page
// sizes it already knows around the committed page, whether the open gallery is a webtoon, records the verdict in the
// browsing history, and reads a webtoon vertically without writing the user's own direction.
// Quick 261126-iq9 (W-1 to W-3) moved the sample to the gallery's middle three pages and asks for their addresses when
// the gallery opens. Quick 261126-trf (P-1 to P-5) adds the passive rule: more than two thirds of the known pages
// extremely tall turn the gallery into a webtoon, a recorded "not a webtoon" included.
// `@MainActor` sits on the members that build a `TestStore`, whose `init` and `state` are main-actor-isolated.
@Suite(.isolatedAppStorage)
struct WebtoonReadingTests {
    private let now = Date(timeIntervalSince1970: 1_000)
    /// A gid the history can key, for the cases that read the persisted verdict back.
    private let validGID = "2421719"

    /// 400 by 1000, a height-to-width ratio of exactly 2.5, which counts as extremely tall (D-05).
    private static func tallSize() throws -> PagePixelSize {
        try #require(PagePixelSize(width: 400, height: 1000))
    }

    /// 400 by 999, just under the ratio.
    private static func shortSize() throws -> PagePixelSize {
        try #require(PagePixelSize(width: 400, height: 999))
    }

    /// A reader of a gallery of `pageCount` pages (ten by default) on `page`, with `setting` and the history in the
    /// case's suite, which knows the sizes of `tallPages` as extremely tall. The default gid is one the history cannot
    /// key, so nothing is persisted.
    private func makeState(
        gid: String = "not-a-gid", setting: Setting, page: Int, tallPages: [Int],
        pageCount: Int = 10, galleryURL: URL? = nil
    ) throws -> ReadingReducer.State {
        let gallery = Gallery(
            gid: gid, token: "token", title: "Webtoon", rating: 0, tags: [], category: .doujinshi,
            pageCount: pageCount, postedDate: now, coverURL: nil, galleryURL: galleryURL
        )
        var state = ReadingReducer.State(gallery: gallery)
        state.$setting.withLock({ $0 = setting })
        state.readingProgress = page
        let tall = try Self.tallSize()
        for tallPage in tallPages {
            state.recordSize(tall, ofPage: tallPage, from: .decodedImage)
        }
        return state
    }

    /// A store of `state`. A test that receives the flush of the debounced progress passes a `TestClock` and advances
    /// it: `ImmediateClock` yields at background priority, which a busy machine can starve past the receive's timeout.
    @MainActor
    private func makeStore(
        _ state: ReadingReducer.State, clock: any Clock<Duration> = ImmediateClock()
    ) -> TestStoreOf<ReadingReducer> {
        TestStore(initialState: state, reducer: ReadingReducer.init) {
            $0.analyticsClient = .noop
            $0.appLaunchAutomationClient = .none
            $0.continuousClock = clock
            $0.cookieClient = .noop
            $0.date = .constant(now)
            $0.downloadClient = .noop
            $0.hapticsClient = .noop
        }
    }

    /// The entry the case's history holds for `gid`.
    private func persistedEntry(gid: String) -> GalleryHistoryEntry? {
        @Shared(.galleryHistory) var history
        return history.first(where: { $0.gid == gid })
    }

    /// Records `isWebtoon` for `gid` in the case's history, as an earlier session would have.
    private func seedVerdict(_ isWebtoon: Bool, gid: String) {
        @Shared(.galleryHistory) var history
        $history.withLock {
            $0.recordWebtoonVerdict(gid: gid, token: "token", isWebtoon: isWebtoon, date: now)
        }
    }

    // MARK: Sampling and threshold (W-1, D-05)

    @Test(arguments: [
        (pageCount: 3, first: 1), (pageCount: 4, first: 1), (pageCount: 5, first: 2),
        (pageCount: 10, first: 4), (pageCount: 26, first: 12), (pageCount: 27, first: 13)
    ])
    func theSampleIsTheMiddleThreePages(pageCount: Int, first: Int) {
        #expect(ReadingReducer.State.webtoonSamplePages(pageCount: pageCount) == first...(first + 2))
    }

    @Test(arguments: [0, 1, 2])
    func aGalleryOfFewerThanThreePagesIsNeverSampled(pageCount: Int) {
        #expect(ReadingReducer.State.webtoonSamplePages(pageCount: pageCount) == nil)
    }

    @Test(arguments: [1, 5, 10])
    func theVerdictReadsTheMiddlePagesWhateverThePage(page: Int) throws {
        let state = try makeState(setting: Setting(), page: page, tallPages: [4, 5, 6])
        #expect(state.webtoonVerdictFromKnownSizes == true)
    }

    // Gallery 4354007 has a cover 797 by 1895 (a ratio of 2.38) before pages many times as tall as wide: the cover
    // is not in the sample, so it cannot decide the gallery.
    @Test
    func aCoverUnderTheRatioNoLongerDecidesTheGallery() throws {
        var state = try makeState(setting: Setting(), page: 1, tallPages: [], pageCount: 26)
        state.recordSize(try #require(PagePixelSize(width: 797, height: 1895)), ofPage: 1, from: .servedURL)
        state.recordSize(try #require(PagePixelSize(width: 800, height: 18_400)), ofPage: 12, from: .servedURL)
        state.recordSize(try #require(PagePixelSize(width: 800, height: 12_640)), ofPage: 13, from: .servedURL)
        state.recordSize(try #require(PagePixelSize(width: 800, height: 19_200)), ofPage: 14, from: .servedURL)
        #expect(state.webtoonVerdictFromKnownSizes == true)
    }

    @Test
    func onePageUnderTheRatioMakesNoWebtoon() throws {
        var state = try makeState(setting: Setting(), page: 5, tallPages: [4, 5])
        let short = try Self.shortSize()
        state.recordSize(short, ofPage: 6, from: .servedURL)
        #expect(state.webtoonVerdictFromKnownSizes == false)
    }

    @Test
    func aSampledPageWithoutAKnownSizeLeavesNoVerdict() throws {
        let state = try makeState(setting: Setting(), page: 5, tallPages: [4, 5, 7])
        #expect(state.webtoonVerdictFromKnownSizes == nil)
    }

    // MARK: Detection in the reader (D-02, D-06, D-07)

    // A decoded size completes the sample mid-session: the reader reads the gallery vertically, one page per
    // position even in a landscape two-page setting, and the user's own direction and two-page choice stay as they
    // were.
    @MainActor
    @Test
    func aVerdictMidSessionReadsTheGalleryVerticallyWithoutWritingTheDirection() async throws {
        let setting = Setting(
            readingDirection: .rightToLeft, alwaysReadsWebtoonsVertically: true, enableDualPageMode: true
        )
        var state = try makeState(setting: setting, page: 5, tallPages: [4, 5])
        state.layoutIsLandscape = true
        let store = makeStore(state)
        let tall = try Self.tallSize()

        await store.send(.onWebImageSucceeded(6, pixelSize: tall)) {
            $0.imageURLLoadingStates[6] = .idle
            $0.webImageLoadSuccessIndices.insert(6)
            $0.pageSizes[6] = KnownPageSize(pixelSize: tall, source: .decodedImage)
            $0.isWebtoon = true
            $0.toast = .success(title: .webtoonToastTitle, caption: .webtoonToastMessage)
        }

        let layout = store.state.containerDataSource(setting: store.state.readingSetting, isLandscape: true)
        #expect(store.state.readingSetting.readingDirection == .vertical)
        #expect(layout == Array(1...10))
        #expect(store.state.landingPage(of: 6) == 6)
        #expect(store.state.setting.readingDirection == .rightToLeft)
        #expect(store.state.setting.enableDualPageMode)
        await store.finish()
    }

    // The verdict lands on the first action once the middle sizes are known, whatever page is committed, and is
    // recorded for a gallery that had no history entry yet; the progress the commit then saves lands in the same entry.
    @MainActor
    @Test
    func theVerdictIsRecordedInTheHistoryWithTheProgress() async throws {
        let state = try makeState(
            gid: validGID, setting: Setting(alwaysReadsWebtoonsVertically: true), page: 1, tallPages: [4, 5, 6]
        )
        let clock = TestClock()
        let store = makeStore(state, clock: clock)

        await store.send(.pagerSettled(shown: 2, generation: 0)) {
            _ = $0.position.pagerSettled(shown: 2, generation: 0)
            $0.isWebtoon = true
        }
        await store.receive(\.syncReadingProgress) {
            $0.visitedPages = [2]
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.flushReadingProgress)
        await store.finish()

        let entry = try #require(persistedEntry(gid: validGID))
        #expect(entry.isWebtoon == true)
        #expect(entry.readingProgress == 2)
        #expect(entry.token == "token")
    }

    @MainActor
    @Test
    func withTheOptionOffNothingIsDetectedOrRecorded() async throws {
        let state = try makeState(
            gid: validGID, setting: Setting(readingDirection: .rightToLeft), page: 1, tallPages: [4, 5, 6]
        )
        let clock = TestClock()
        let store = makeStore(state, clock: clock)

        await store.send(.pagerSettled(shown: 5, generation: 0)) {
            _ = $0.position.pagerSettled(shown: 5, generation: 0)
        }
        await store.receive(\.syncReadingProgress) {
            $0.visitedPages = [5]
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.flushReadingProgress)
        await store.finish()

        #expect(store.state.readingSetting.readingDirection == .rightToLeft)
        let entry = try #require(persistedEntry(gid: validGID))
        #expect(entry.isWebtoon == nil)
        #expect(entry.readingProgress == 5)
    }

    // The settings sheet writes the option straight to the shared setting; the action the view then sends lets the
    // reader decide on sizes it already knows, without waiting for another page.
    @MainActor
    @Test
    func turningTheOptionOnDecidesAtOnce() async throws {
        let state = try makeState(
            setting: Setting(alwaysReadsWebtoonsVertically: true), page: 5, tallPages: [4, 5, 6]
        )
        let store = makeStore(state)

        await store.send(.webtoonReadingPreferenceChanged) {
            $0.isWebtoon = true
        }
        await store.finish()
    }

    @MainActor
    @Test
    func notEveryPageExtremelyTallRecordsNoWebtoon() async throws {
        let setting = Setting(readingDirection: .rightToLeft, alwaysReadsWebtoonsVertically: true)
        let state = try makeState(setting: setting, page: 5, tallPages: [4, 5])
        let store = makeStore(state)
        let short = try Self.shortSize()

        await store.send(.onWebImageSucceeded(6, pixelSize: short)) {
            $0.imageURLLoadingStates[6] = .idle
            $0.webImageLoadSuccessIndices.insert(6)
            $0.pageSizes[6] = KnownPageSize(pixelSize: short, source: .decodedImage)
            $0.isWebtoon = false
        }

        #expect(store.state.readingSetting.readingDirection == .rightToLeft)
        await store.finish()
    }

    // MARK: Asking for the middle pages at open (W-2, W-3)

    private static let remoteGalleryURL = URL(string: "https://example.com/g/42/abc123/")

    // A hundred-page gallery has its middle pages, 49 to 51, in a batch (41 to 80) the opening page's batch (1 to 40)
    // does not cover, so they are asked for; the three sends make one request, which marks the batch loading.
    @MainActor
    @Test
    func openingAnUncheckedGalleryAsksForTheMiddlePages() async throws {
        let state = try makeState(
            gid: validGID, setting: Setting(alwaysReadsWebtoonsVertically: true), page: 1, tallPages: [],
            pageCount: 100, galleryURL: Self.remoteGalleryURL
        )
        let store = makeStore(state)
        // Past the asserted actions the requests answer at any moment (the test network guard fails them).
        store.exhaustivity = .off(showSkippedAssertions: false)
        let batch = store.state.previewConfig.batchRange(index: 49)
        #expect(batch == 41...80)

        await store.send(.onPresented)
        await store.receive(\.fetchImageURLs, 49)
        await store.receive(\.fetchImageURLs, 50)
        await store.receive(\.fetchImageURLs, 51)
        await store.receive(\.fetchThumbnailURLs, 49) {
            for page in batch { $0.imageURLLoadingStates[page] = .loading }
        }
        await store.skipInFlightEffects(strict: false)

        for page in batch {
            #expect(store.state.imageURLLoadingStates[page] == .loading)
        }
    }

    @MainActor
    @Test(arguments: [
        (optionOn: false, verdict: nil as Bool?), (optionOn: true, verdict: true as Bool?),
        (optionOn: true, verdict: false as Bool?)
    ])
    func openingAsksForNoMiddlePageWithoutTheOptionOrWithAVerdict(optionOn: Bool, verdict: Bool?) async throws {
        if let verdict {
            seedVerdict(verdict, gid: validGID)
        }
        let state = try makeState(
            gid: validGID, setting: Setting(alwaysReadsWebtoonsVertically: optionOn), page: 1, tallPages: [],
            pageCount: 100, galleryURL: Self.remoteGalleryURL
        )
        let store = makeStore(state)
        store.exhaustivity = .off(showSkippedAssertions: false)
        let batch = store.state.previewConfig.batchRange(index: 49)

        await store.send(.onPresented)
        await store.receive(\.fetchImageURLs, 1)
        await store.skipInFlightEffects(strict: false)

        for page in batch {
            #expect(store.state.imageURLLoadingStates[page] != .loading)
        }
    }

    // The served addresses of the three middle pages name their sizes, which are tall: the gallery is a webtoon, the
    // reader turns vertical with the toast, and the history keeps the verdict.
    @MainActor
    @Test
    func theMiddlePagesServedSizesDecideTheGallery() async throws {
        var state = try makeState(
            gid: validGID, setting: Setting(readingDirection: .rightToLeft, alwaysReadsWebtoonsVertically: true),
            page: 1, tallPages: [], pageCount: 100, galleryURL: Self.remoteGalleryURL
        )
        let batch = state.previewConfig.batchRange(index: 49)
        for page in batch {
            state.imageURLLoadingStates[page] = .loading
        }
        let store = makeStore(state)
        let heights = [49: 18_400, 50: 12_640, 51: 19_200]
        var imageURLs = [Int: URL]()
        var servedSizes = [Int: KnownPageSize]()
        for (page, height) in heights {
            imageURLs[page] = try Self.servedURL(width: 800, height: height)
            servedSizes[page] = try KnownPageSize(
                pixelSize: #require(PagePixelSize(width: 800, height: height)), source: .servedURL
            )
        }

        await store.send(.fetchNormalImageURLsDone(index: 49, result: .success((imageURLs, [:])))) {
            for page in batch {
                $0.imageURLLoadingStates[page] = .idle
            }
            $0.imageURLs = imageURLs
            $0.pageSizes = servedSizes
            $0.isWebtoon = true
            $0.toast = .success(title: .webtoonToastTitle, caption: .webtoonToastMessage)
        }
        await store.finish()

        #expect(store.state.readingSetting.readingDirection == .vertical)
        #expect(persistedEntry(gid: validGID)?.isWebtoon == true)
    }

    // A failed fetch of the middle batch is an ordinary failed batch: no verdict, and nothing asks again (W-3).
    @MainActor
    @Test
    func aFailedMiddleFetchRecordsNoVerdictAndAsksNoMore() async throws {
        var state = try makeState(
            gid: validGID, setting: Setting(alwaysReadsWebtoonsVertically: true),
            page: 1, tallPages: [], pageCount: 100, galleryURL: Self.remoteGalleryURL
        )
        let batch = state.previewConfig.batchRange(index: 49)
        for page in batch {
            state.imageURLLoadingStates[page] = .loading
        }
        let store = makeStore(state)

        await store.send(.fetchThumbnailURLsDone(index: 49, result: .failure(.notFound))) {
            for page in batch {
                $0.imageURLLoadingStates[page] = .failed(.notFound)
            }
            $0.surfacedErrorKinds = [.notFound]
        }
        await store.finish()

        #expect(store.state.isWebtoon == nil)
        #expect(persistedEntry(gid: validGID) == nil)
    }

    // MARK: Asking for the middle pages in a multi-page viewer (W-2)

    /// A multi-page viewer's list for a gallery of `pageCount` pages, naming the original sizes in `sizes`.
    private static func imageList(pageCount: Int, sizes: [Int: PagePixelSize] = [:]) -> MPVImageList {
        MPVImageList(
            key: "mpv", imageKeys: Dictionary(uniqueKeysWithValues: (1...pageCount).map({ ($0, "key-\($0)") })),
            originalSizes: sizes
        )
    }

    /// The reader of gallery 4354007's shape (26 pages, middle pages 12 to 14) as it stands after opening on page 1:
    /// the opening page's batch, which holds the middle pages, is loading. A viewer's address request needs a numeric
    /// gid: with the default one, every request the reader sends stops at that guard, so a case asserts exactly which
    /// pages are asked for without reaching the network.
    private func openingViewerState(gid: String = "not-a-gid") throws -> ReadingReducer.State {
        var state = try makeState(
            gid: gid, setting: Setting(readingDirection: .rightToLeft, alwaysReadsWebtoonsVertically: true),
            page: 1, tallPages: [], pageCount: 26, galleryURL: Self.remoteGalleryURL
        )
        for page in state.previewConfig.batchRange(index: 1) {
            state.imageURLLoadingStates[page] = .loading
        }
        return state
    }

    // In a viewer the request made at open falls into the opening page's batch, which fetches only the viewer's
    // list; the list resolves the first pages and the shown one. The middle pages are asked for again once its keys
    // are known, page by page.
    @MainActor
    @Test
    func aViewersListAsksForTheMiddlePagesItLeavesUnsized() async throws {
        let state = try openingViewerState(gid: validGID)
        let batch = state.previewConfig.batchRange(index: 1)
        let store = makeStore(state)
        store.exhaustivity = .off(showSkippedAssertions: false)

        await store.send(.fetchMPVKeysDone(index: 1, result: .success(Self.imageList(pageCount: 26)))) {
            $0.mpvKey = "mpv"
            for page in batch { $0.imageURLLoadingStates[page] = .idle }
        }
        for page in 12...14 {
            await store.receive({ action in
                guard case .fetchMPVImageURL(page, false) = action else { return false }
                return true
            }) {
                $0.imageURLLoadingStates[page] = .loading
            }
        }
        await store.skipInFlightEffects(strict: false)
    }

    // A list that names the middle pages' sizes decides the gallery as it arrives and asks for no middle page: only
    // the first pages, which the list resolves anyway, are asked for, and nothing else is received.
    @MainActor
    @Test
    func aViewersListThatSizesTheMiddlePagesDecidesWithoutAsking() async throws {
        let state = try openingViewerState()
        let batch = state.previewConfig.batchRange(index: 1)
        let store = makeStore(state)
        let tall = try Self.tallSize()
        let sizes = [12: tall, 13: tall, 14: tall]
        let imageList = Self.imageList(pageCount: 26, sizes: sizes)

        await store.send(.fetchMPVKeysDone(index: 1, result: .success(imageList))) {
            $0.mpvKey = "mpv"
            $0.mpvImageKeys = imageList.imageKeys
            for page in batch { $0.imageURLLoadingStates[page] = .idle }
            $0.pageSizes = sizes.mapValues({ KnownPageSize(pixelSize: $0, source: .originalFile) })
            $0.isWebtoon = true
            $0.toast = .success(title: .webtoonToastTitle, caption: .webtoonToastMessage)
        }
        for _ in 1...3 {
            await store.receive(\.fetchMPVImageURL)
        }
        await store.finish()
    }

    // A list the reader refuses (its keys do not match the page count) leaves no key: nothing asks for the middle
    // pages, so the refused batch is not fetched again (W-3).
    @MainActor
    @Test
    func aRefusedViewersListAsksForNoMiddlePage() async throws {
        let state = try openingViewerState()
        let batch = state.previewConfig.batchRange(index: 1)
        let store = makeStore(state)

        await store.send(.fetchMPVKeysDone(index: 1, result: .success(Self.imageList(pageCount: 25)))) {
            for page in batch { $0.imageURLLoadingStates[page] = .failed(.notFound) }
            $0.surfacedErrorKinds = [.notFound]
        }
        await store.finish()
    }

    /// A URL the site would serve for a page of `width` by `height` pixels, whose file identifier names the size.
    private static func servedURL(width: Int, height: Int) throws -> URL {
        try #require(URL(string: """
            https://example.hath.network/h/ea42b28bceeae68f1f6adb414da61d186b3d126b-311480-\(width)-\(height)-jpg\
            /keystamp=1694132700-fd778f8260;fileindex=132044713;xres=1280/87052610_5090394_0.jpg
            """))
    }

    // MARK: A recorded verdict (D-06, D-07)

    // A gallery recorded as a webtoon opens vertically at once, with nothing to decide and no toast; with the option
    // off it reads in the user's direction again, and the verdict is kept for when the option comes back.
    @Test
    func aRecordedWebtoonOpensVerticallyAtOnce() throws {
        seedVerdict(true, gid: validGID)
        let setting = Setting(readingDirection: .rightToLeft, alwaysReadsWebtoonsVertically: true)
        let state = try makeState(gid: validGID, setting: setting, page: 5, tallPages: [])

        #expect(state.isWebtoon == true)
        #expect(state.readingSetting.readingDirection == .vertical)
        #expect(state.setting.readingDirection == .rightToLeft)
        #expect(state.toast == nil)
        state.$setting.withLock({ $0.alwaysReadsWebtoonsVertically = false })
        #expect(state.readingSetting.readingDirection == .rightToLeft)
        #expect(state.isWebtoon == true)
    }

    // A recorded "not a webtoon" only spares the open its middle-page fetch (P-3): the pages read can still turn the
    // gallery into a webtoon, and the turn replaces the recorded verdict.
    @MainActor
    @Test
    func aRecordedNoWebtoonIsTurnedByThePagesRead() async throws {
        seedVerdict(false, gid: validGID)
        let state = try makeState(
            gid: validGID, setting: Setting(readingDirection: .rightToLeft, alwaysReadsWebtoonsVertically: true),
            page: 5, tallPages: [4, 5, 6]
        )
        #expect(state.isWebtoon == false)
        let store = makeStore(state)

        await store.send(.webtoonReadingPreferenceChanged) {
            $0.isWebtoon = true
            $0.toast = .success(title: .webtoonToastTitle, caption: .webtoonToastMessage)
        }
        #expect(store.state.readingSetting.readingDirection == .vertical)
        #expect(persistedEntry(gid: validGID)?.isWebtoon == true)
        await store.finish()
    }

    // A recorded webtoon stays one (P-2): pages that are not tall never turn it back.
    @MainActor
    @Test
    func aRecordedWebtoonIsNeverTurnedBack() async throws {
        seedVerdict(true, gid: validGID)
        var state = try makeState(
            gid: validGID, setting: Setting(alwaysReadsWebtoonsVertically: true), page: 5, tallPages: []
        )
        let short = try Self.shortSize()
        for page in 1...6 {
            state.recordSize(short, ofPage: page, from: .decodedImage)
        }
        let store = makeStore(state)

        await store.send(.webtoonReadingPreferenceChanged)
        #expect(store.state.isWebtoon == true)
        #expect(persistedEntry(gid: validGID)?.isWebtoon == true)
        await store.finish()
    }

    // MARK: Passive detection (P-1 to P-5 of quick 261126-trf)

    @Test
    func moreThanTwoThirdsOfTheKnownPagesTallMakeAWebtoon() throws {
        var state = try makeState(setting: Setting(), page: 1, tallPages: [1, 2, 3, 20], pageCount: 26)
        state.recordSize(try Self.shortSize(), ofPage: 21, from: .originalFile)
        #expect(state.mostKnownPagesAreExtremelyTall)
    }

    @Test
    func exactlyTwoThirdsOfTheKnownPagesTallMakeNoWebtoon() throws {
        var state = try makeState(setting: Setting(), page: 1, tallPages: [1, 2, 3, 4], pageCount: 26)
        let short = try Self.shortSize()
        state.recordSize(short, ofPage: 5, from: .servedURL)
        state.recordSize(short, ofPage: 6, from: .servedURL)
        #expect(!state.mostKnownPagesAreExtremelyTall)
    }

    @Test
    func fewerThanThreeKnownPagesMakeNoWebtoon() throws {
        let state = try makeState(setting: Setting(), page: 1, tallPages: [1, 2], pageCount: 26)
        #expect(!state.mostKnownPagesAreExtremelyTall)
    }

    // The middle sample of a 26-page gallery holds a short page, so it records no webtoon; the pages read then turn
    // the gallery once more than two thirds of every known page are tall, with the toast of a mid-session verdict.
    @MainActor
    @Test
    func aShortMiddlePageIsOverturnedByThePagesRead() async throws {
        let setting = Setting(readingDirection: .rightToLeft, alwaysReadsWebtoonsVertically: true)
        var state = try makeState(setting: setting, page: 1, tallPages: [12, 14], pageCount: 26)
        let short = try Self.shortSize()
        let tall = try Self.tallSize()
        state.recordSize(short, ofPage: 13, from: .servedURL)
        let store = makeStore(state)

        // Four known pages, two tall: the middle sample decides no webtoon.
        await store.send(.onWebImageSucceeded(1, pixelSize: short)) {
            $0.imageURLLoadingStates[1] = .idle
            $0.webImageLoadSuccessIndices.insert(1)
            $0.pageSizes[1] = KnownPageSize(pixelSize: short, source: .decodedImage)
            $0.isWebtoon = false
        }
        // Three of five, then four of six: not more than two thirds yet.
        for page in 2...3 {
            await store.send(.onWebImageSucceeded(page, pixelSize: tall)) {
                $0.imageURLLoadingStates[page] = .idle
                $0.webImageLoadSuccessIndices.insert(page)
                $0.pageSizes[page] = KnownPageSize(pixelSize: tall, source: .decodedImage)
            }
        }
        // Five of seven turns it.
        await store.send(.onWebImageSucceeded(4, pixelSize: tall)) {
            $0.imageURLLoadingStates[4] = .idle
            $0.webImageLoadSuccessIndices.insert(4)
            $0.pageSizes[4] = KnownPageSize(pixelSize: tall, source: .decodedImage)
            $0.isWebtoon = true
            $0.toast = .success(title: .webtoonToastTitle, caption: .webtoonToastMessage)
        }
        #expect(store.state.readingSetting.readingDirection == .vertical)
        #expect(store.state.setting.readingDirection == .rightToLeft)
        await store.finish()
    }

    @MainActor
    @Test
    func withTheOptionOffThePagesReadTurnNothing() async throws {
        let state = try makeState(setting: Setting(), page: 1, tallPages: [1, 2, 3, 20, 21], pageCount: 26)
        let store = makeStore(state)

        await store.send(.webtoonReadingPreferenceChanged)
        #expect(store.state.isWebtoon == nil)
        await store.finish()
    }

    // MARK: Saying why (D-03, D-06)

    // A user who already reads vertically sees nothing change, so the verdict shows no toast.
    @MainActor
    @Test
    func aVerdictThatChangesNothingShowsNoToast() async throws {
        let state = try makeState(
            setting: Setting(alwaysReadsWebtoonsVertically: true), page: 5, tallPages: [4, 5]
        )
        let store = makeStore(state)
        let tall = try Self.tallSize()

        await store.send(.onWebImageSucceeded(6, pixelSize: tall)) {
            $0.imageURLLoadingStates[6] = .idle
            $0.webImageLoadSuccessIndices.insert(6)
            $0.pageSizes[6] = KnownPageSize(pixelSize: tall, source: .decodedImage)
            $0.isWebtoon = true
        }

        #expect(store.state.toast == nil)
        await store.finish()
    }

    // The reader opens its settings on a recorded webtoon: their direction picker is locked.
    @MainActor
    @Test
    func theSettingsOfARecordedWebtoonLockTheirDirectionPicker() async throws {
        seedVerdict(true, gid: validGID)
        let state = try makeState(
            gid: validGID, setting: Setting(readingDirection: .rightToLeft, alwaysReadsWebtoonsVertically: true),
            page: 5, tallPages: []
        )
        let store = makeStore(state)
        store.exhaustivity = .off

        await store.send(.presentReadingSetting)

        let readingSetting = try #require(store.state.destination?.readingSetting)
        #expect(readingSetting.galleryIsWebtoon)
        #expect(readingSetting.locksDirection)
        await store.finish()
    }

    // A verdict that lands while the settings are open locks their picker there and then, and the switch it makes
    // says so in a toast.
    @MainActor
    @Test
    func aVerdictWhileTheSettingsAreOpenLocksTheirPicker() async throws {
        let setting = Setting(readingDirection: .rightToLeft, alwaysReadsWebtoonsVertically: true)
        let state = try makeState(setting: setting, page: 5, tallPages: [4, 5])
        let store = makeStore(state)
        store.exhaustivity = .off
        let tall = try Self.tallSize()

        await store.send(.presentReadingSetting)
        #expect(store.state.destination?.readingSetting?.galleryIsWebtoon == false)
        #expect(store.state.destination?.readingSetting?.locksDirection == false)
        await store.send(.onWebImageSucceeded(6, pixelSize: tall))

        #expect(store.state.destination?.readingSetting?.galleryIsWebtoon == true)
        #expect(store.state.destination?.readingSetting?.locksDirection == true)
        #expect(store.state.toast == .success(title: .webtoonToastTitle, caption: .webtoonToastMessage))
        await store.finish()
    }

    // The Setting tab opens the editor with no gallery, so its picker is never locked; the reader's editor locks it
    // only while the option is on.
    @Test
    func onlyTheReadersSettingsOfAWebtoonLockTheDirection() {
        let settingTab = ReadingSettingReducer.State()
        let reader = ReadingSettingReducer.State(galleryIsWebtoon: true)
        settingTab.$setting.withLock({ $0.alwaysReadsWebtoonsVertically = true })
        #expect(!settingTab.locksDirection)
        #expect(reader.locksDirection)
        reader.$setting.withLock({ $0.alwaysReadsWebtoonsVertically = false })
        #expect(!reader.locksDirection)
    }
}
