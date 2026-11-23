import AnalyticsClient
import AppComponents
import AppModels
import ComposableArchitecture
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

    /// A reader of a ten-page gallery on `page`, with `setting` and the history in the case's suite, which knows the
    /// sizes of `tallPages` as extremely tall. The default gid is one the history cannot key, so nothing is persisted.
    private func makeState(
        gid: String = "not-a-gid", setting: Setting, page: Int, tallPages: [Int]
    ) throws -> ReadingReducer.State {
        let gallery = Gallery(
            gid: gid, token: "token", title: "Webtoon", rating: 0, tags: [], category: .doujinshi,
            pageCount: 10, postedDate: now, coverURL: nil, galleryURL: nil
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
            $0.continuousClock = clock
            $0.date = .constant(now)
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

    // MARK: Sampling and threshold (D-04, D-05)

    @Test(arguments: [
        (page: 1, pageCount: 10, first: 1), (page: 2, pageCount: 10, first: 1), (page: 5, pageCount: 10, first: 4),
        (page: 9, pageCount: 10, first: 8), (page: 10, pageCount: 10, first: 8), (page: 25, pageCount: 10, first: 8),
        (page: 2, pageCount: 3, first: 1)
    ])
    func theSampleIsTheCommittedPageAndItsNeighboursMovedInsideTheGallery(page: Int, pageCount: Int, first: Int) {
        #expect(ReadingReducer.State.webtoonSamplePages(around: page, pageCount: pageCount) == first...(first + 2))
    }

    @Test(arguments: [0, 1, 2])
    func aGalleryOfFewerThanThreePagesIsNeverSampled(pageCount: Int) {
        #expect(ReadingReducer.State.webtoonSamplePages(around: 1, pageCount: pageCount) == nil)
    }

    @Test(arguments: [
        (page: 1, tallPages: [1, 2, 3]), (page: 5, tallPages: [4, 5, 6]), (page: 10, tallPages: [8, 9, 10])
    ])
    func threePagesOfExactlyTheRatioMakeAWebtoon(page: Int, tallPages: [Int]) throws {
        let state = try makeState(setting: Setting(), page: page, tallPages: tallPages)
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

    // A newly committed page completes the sample, and the verdict is recorded for a gallery that had no history
    // entry yet; the progress the commit then saves lands in the same entry.
    @MainActor
    @Test
    func aCommittedPageDecidesAndTheHistoryRecordsTheVerdict() async throws {
        let state = try makeState(
            gid: validGID, setting: Setting(alwaysReadsWebtoonsVertically: true), page: 1, tallPages: [4, 5, 6]
        )
        let clock = TestClock()
        let store = makeStore(state, clock: clock)

        await store.send(.pagerSettled(shown: 5, generation: 0)) {
            _ = $0.position.pagerSettled(shown: 5, generation: 0)
            $0.isWebtoon = true
        }
        await store.receive(\.syncReadingProgress) {
            $0.visitedPages = [5]
        }
        await clock.advance(by: .seconds(1))
        await store.receive(\.flushReadingProgress)
        await store.finish()

        let entry = try #require(persistedEntry(gid: validGID))
        #expect(entry.isWebtoon == true)
        #expect(entry.readingProgress == 5)
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

    // A gallery is detected once: a recorded "not a webtoon" stands even when every sampled page is now tall.
    @MainActor
    @Test
    func aRecordedVerdictIsNotCheckedAgain() async throws {
        seedVerdict(false, gid: validGID)
        let state = try makeState(
            gid: validGID, setting: Setting(readingDirection: .rightToLeft, alwaysReadsWebtoonsVertically: true),
            page: 5, tallPages: [4, 5, 6]
        )
        let store = makeStore(state)

        await store.send(.webtoonReadingPreferenceChanged)
        #expect(store.state.isWebtoon == false)
        #expect(store.state.readingSetting.readingDirection == .rightToLeft)
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
