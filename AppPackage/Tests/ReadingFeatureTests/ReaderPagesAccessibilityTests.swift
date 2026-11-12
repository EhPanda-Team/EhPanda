import AppModels
import ComposableArchitecture
import Foundation
@testable import ReadingFeature
import Sharing
import Testing

// The reader's pages are one accessibility element in every reading direction (owner, 2026-10-11). These cases pin
// what the element reads; `ReaderPageSyncUITests.testThePagesAreOneElementReadingTheirPage` finds it in the app.
@MainActor
@Suite
struct ReaderPagesAccessibilityTests {
    @Test
    func aPageReadsItsPosition() {
        let value = ReaderPagesAccessibility.description(of: [4], failedPages: [], total: 31)

        #expect(String(localized: value) == String(localized: .accessibilityPageOf(current: 4, total: 31)))
    }

    @Test
    func aSpreadReadsItsRange() {
        let value = ReaderPagesAccessibility.description(of: [4, 5], failedPages: [], total: 31)

        #expect(String(localized: value) == String(localized: .accessibilityPagesOf(first: 4, last: 5, total: 31)))
    }

    @Test
    func aFailedPageReadsThatItFailed() {
        let value = ReaderPagesAccessibility.description(of: [4], failedPages: [4], total: 31)

        let expected = LocalizedStringResource.accessibilityPageStatus(
            String(localized: .accessibilityPageOf(current: 4, total: 31)),
            String(localized: .accessibilityFailedToLoad)
        )
        #expect(String(localized: value) == String(localized: expected))
    }

    @Test
    func aSpreadNamesItsFailedPageUnlessBothFailed() {
        let range = String(localized: .accessibilityPagesOf(first: 4, last: 5, total: 31))
        let oneFailed = ReaderPagesAccessibility.description(of: [4, 5], failedPages: [5], total: 31)
        let bothFailed = ReaderPagesAccessibility.description(of: [4, 5], failedPages: [4, 5], total: 31)

        let namesPage = LocalizedStringResource.accessibilityPageStatus(
            range, String(localized: .accessibilityPageFailedToLoad(page: 5))
        )
        let failed = LocalizedStringResource.accessibilityPageStatus(
            range, String(localized: .accessibilityFailedToLoad)
        )
        #expect(String(localized: oneFailed) == String(localized: namesPage))
        #expect(String(localized: bothFailed) == String(localized: failed))
    }

    // The element reads the pages of the position the reader's page lies in: one page, or the
    // spread a landscape dual-page layout shows it in.
    @Test
    func theElementReadsThePagesOfThePositionTheReadersPageLiesIn() {
        let state = Self.state(page: 4)

        #expect(ReaderPagesAccessibility.shownPages(at: 4, state: state, isLandscape: false) == [4])
        #expect(ReaderPagesAccessibility.shownPages(at: 4, state: state, isLandscape: true) == [3, 4])
        #expect(ReaderPagesAccessibility.shownPages(at: 11, state: state, isLandscape: false).isEmpty)
    }

    // Next and previous turn by one position from the page the reader names, and reach the reducer
    // as its one turn intent, which sends the pager to the turn's page.
    @Test(arguments: [(step: 1, page: 5), (step: -1, page: 1)])
    func nextAndPreviousSendTheOneTurnIntent(step: Int, page: Int) async {
        let state = Self.state(page: 4, isLandscape: true)
        let store = TestStore(initialState: state, reducer: ReadingReducer.init)
        let target = PageHandler().page(
            turningFrom: state.position.displayedPage, by: step, pageCount: state.gallery.pageCount,
            setting: state.setting, isLandscape: true
        )

        await store.send(.turn(toPage: target)) {
            _ = $0.position.turn(to: page, pageCount: 10)
        }
        #expect(store.state.position.issued?.command == .drive(page: page, generation: 0))
        await store.finish()
    }

    private static func state(page: Int, isLandscape: Bool? = nil) -> ReadingReducer.State {
        var gallery = Gallery.preview
        gallery.pageCount = 10
        var state = withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            ReadingReducer.State(gallery: gallery)
        }
        state.$setting.withLock({ $0 = Setting(readingDirection: .leftToRight, enableDualPageMode: true) })
        state.layoutIsLandscape = isLandscape
        state.readingProgress = page
        return state
    }
}
