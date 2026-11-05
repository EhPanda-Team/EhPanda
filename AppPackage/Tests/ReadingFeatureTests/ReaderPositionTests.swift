@testable import ReadingFeature
import SwiftUI
import Testing

// Pins the rules that keep the reader's one page (`ReaderPosition`) on the page the screen shows, ported from the
// turn gate they replace (17-READER-ROOT-CAUSE.md §3). The paging ScrollView can drop a position handed to it while
// it moves or comes to rest, and stay short of it: a turn that arrives while the pager animates is held and sent once
// the pager is at rest, and a pager at rest on another page than the turn's is sent again, until the page shown is
// committed instead (DD-02). Every observation carries the generation of the pager that made it; a rebuilt pager
// starts a new one, and an older pager's observations change nothing.
@Suite
struct ReaderPositionTests {
    private static let pageCount = 200

    /// A position on `page` with no turn under way, at rest, in the first generation.
    private func position(on page: Int = 106) -> ReaderPosition {
        ReaderPosition(page: page)
    }

    // MARK: Ported turn-gate rules

    @Test
    func aTurnFromRestIsSentAtOnce() {
        var position = position()
        let command = position.turn(to: 107, pageCount: Self.pageCount)
        #expect(command == .drive(page: 107, generation: 0))
        #expect(position.request?.isHeld == false)
        #expect(position.displayedPage == 107)
        #expect(position.page == 106)
    }

    @Test
    func aTurnWhileThePagerAnimatesIsHeldAndSentAtRest() {
        var position = position()
        let first = position.turn(to: 107, pageCount: Self.pageCount)
        let sendsOnAnimating = position.pagerPhaseChanged(to: .animating, generation: 0)
        let second = position.turn(to: 108, pageCount: Self.pageCount)
        let third = position.turn(to: 109, pageCount: Self.pageCount)
        #expect(first == .drive(page: 107, generation: 0))
        #expect(sendsOnAnimating == nil)
        #expect(second == nil)
        #expect(third == nil)
        #expect(position.request?.isHeld == true)
        // The latest turn wins, and the reader names it while it is held.
        #expect(position.displayedPage == 109)

        let sendsAtRest = position.pagerPhaseChanged(to: .idle, generation: 0)
        #expect(sendsAtRest == .drive(page: 109, generation: 0))
        #expect(position.request?.isHeld == false)
        let afterRest = position.turn(to: 110, pageCount: Self.pageCount)
        #expect(afterRest == .drive(page: 110, generation: 0))
    }

    @Test
    func restWithNothingHeldSendsNothing() {
        var position = position()
        let sendsOnAnimating = position.pagerPhaseChanged(to: .animating, generation: 0)
        let sendsAtRest = position.pagerPhaseChanged(to: .idle, generation: 0)
        #expect(sendsOnAnimating == nil)
        #expect(sendsAtRest == nil)
    }

    @Test(arguments: [ScrollPhase.tracking, .interacting, .decelerating])
    func theReadersOwnScrollDropsTheHeldTurn(phase: ScrollPhase) {
        var position = position()
        _ = position.pagerPhaseChanged(to: .animating, generation: 0)
        let held = position.turn(to: 107, pageCount: Self.pageCount)
        let sendsOnTakeOver = position.pagerPhaseChanged(to: PagerMotion(phase), generation: 0)
        #expect(held == nil)
        #expect(sendsOnTakeOver == nil)
        #expect(position.request == nil)
        #expect(position.displayedPage == 106)

        let admitted = position.turn(to: 108, pageCount: Self.pageCount)
        let sendsAtRest = position.pagerPhaseChanged(to: .idle, generation: 0)
        #expect(admitted == .drive(page: 108, generation: 0))
        #expect(sendsAtRest == nil)
    }

    /// A pager built anew, after a forced refresh or a change of direction, starts at rest and reports no phase until
    /// it moves. The motion the old pager left mid-animation must not go on holding the new pager's turns.
    @Test
    func aPagerBuiltAnewAdmitsTurnsAPagerLeftMidAnimationHeld() {
        var position = position()
        _ = position.pagerPhaseChanged(to: .animating, generation: 0)
        let held = position.turn(to: 107, pageCount: Self.pageCount)
        _ = position.pagerRebuilt()
        let admitted = position.turn(to: 108, pageCount: Self.pageCount)
        #expect(held == nil)
        #expect(admitted == .drive(page: 108, generation: 1))
        #expect(position.request?.isHeld == false)
    }

    /// The new pager is placed on the held turn's target, so its first rest sends nothing.
    @Test
    func aPagerBuiltAnewDropsTheTurnHeldForTheOldOne() {
        var position = position()
        _ = position.pagerPhaseChanged(to: .animating, generation: 0)
        _ = position.turn(to: 107, pageCount: Self.pageCount)
        let placement = position.pagerRebuilt()
        let sendsAtFirstRest = position.pagerPhaseChanged(to: .idle, generation: 1)
        #expect(placement == .place(page: 107, generation: 1))
        #expect(sendsAtFirstRest == nil)
        #expect(position.page == 107)
    }

    /// Without a phase report from the new pager, the page it shows is still taken at rest. With no turn left under
    /// way, the page shown is the page.
    @Test
    func aPagerBuiltAnewIsCheckedAtRest() {
        var position = position(on: 107)
        _ = position.pagerPhaseChanged(to: .animating, generation: 0)
        _ = position.pagerRebuilt()
        let command = position.pagerSettled(shown: 106, generation: 1)
        #expect(command == nil)
        #expect(position.page == 106)
    }

    @Test
    func aPagerBuiltAnewStartsTheCountOver() {
        var position = position()
        _ = position.turn(to: 107, pageCount: Self.pageCount)
        _ = position.pagerSettled(shown: 106, generation: 0)
        _ = position.pagerRebuilt()
        _ = position.turn(to: 110, pageCount: Self.pageCount)
        let tries = (0..<ReaderPosition.retryLimit).map({ _ in position.pagerSettled(shown: 106, generation: 1) })
        #expect(tries == Array(repeating: .drive(page: 110, generation: 1), count: ReaderPosition.retryLimit))
    }

    @Test
    func aPagerAtRestOnAnotherPageIsSentToTheTurnAgain() {
        var position = position()
        _ = position.turn(to: 107, pageCount: Self.pageCount)
        _ = position.pagerPhaseChanged(to: .animating, generation: 0)
        _ = position.pagerPhaseChanged(to: .idle, generation: 0)
        let command = position.pagerSettled(shown: 106, generation: 0)
        #expect(command == .drive(page: 107, generation: 0))
        #expect(position.request?.tries == 1)
    }

    @Test
    func aPagerAtRestOnTheTurnIsLeftAlone() {
        var position = position()
        _ = position.turn(to: 107, pageCount: Self.pageCount)
        let noSinglePage = position.pagerSettled(shown: nil, generation: 0)
        #expect(noSinglePage == nil)
        #expect(position.request?.target == 107)

        let onTheTurn = position.pagerSettled(shown: 107, generation: 0)
        #expect(onTheTurn == nil)
        #expect(position.page == 107)
        #expect(position.request == nil)
    }

    @Test(arguments: [ScrollPhase.animating, .tracking, .interacting, .decelerating])
    func aMovingPagerIsNotCorrected(phase: ScrollPhase) {
        var position = position()
        _ = position.turn(to: 107, pageCount: Self.pageCount)
        _ = position.pagerPhaseChanged(to: PagerMotion(phase), generation: 0)
        let before = position
        let command = position.pagerSettled(shown: 105, generation: 0)
        #expect(command == nil)
        #expect(position == before)
    }

    /// The indicator must never name a page the screen does not show: once the pager has missed the turn
    /// `retryLimit` times in a row, the page on screen is committed (DD-02).
    @Test
    func thePageFollowsTheScreenWhenThePagerKeepsMissingTheTurn() {
        var position = position()
        _ = position.turn(to: 107, pageCount: Self.pageCount)
        let tries = (0..<ReaderPosition.retryLimit).map({ _ in position.pagerSettled(shown: 106, generation: 0) })
        let beyondTheLimit = position.pagerSettled(shown: 106, generation: 0)
        #expect(tries == Array(repeating: .drive(page: 107, generation: 0), count: ReaderPosition.retryLimit))
        #expect(beyondTheLimit == nil)
        #expect(position.page == 106)
        #expect(position.request == nil)

        // With the page on the page on screen, the two are in step and the next turn's count starts over.
        let inStep = position.pagerSettled(shown: 106, generation: 0)
        _ = position.turn(to: 110, pageCount: Self.pageCount)
        let nextMiss = position.pagerSettled(shown: 106, generation: 0)
        #expect(inStep == nil)
        #expect(nextMiss == .drive(page: 110, generation: 0))
    }

    @Test
    func landingOnTheTurnStartsTheCountOver() {
        var position = position()
        _ = position.turn(to: 107, pageCount: Self.pageCount)
        _ = position.pagerSettled(shown: 106, generation: 0)
        _ = position.pagerSettled(shown: 107, generation: 0)
        _ = position.turn(to: 108, pageCount: Self.pageCount)
        let tries = (0..<ReaderPosition.retryLimit).map({ _ in position.pagerSettled(shown: 107, generation: 0) })
        #expect(tries == Array(repeating: .drive(page: 108, generation: 0), count: ReaderPosition.retryLimit))
    }

    /// A try counted for one turn's miss is not carried over to the next turn's.
    @Test
    func aNewTurnStartsTheCountOver() {
        var position = position()
        _ = position.turn(to: 107, pageCount: Self.pageCount)
        _ = position.pagerSettled(shown: 106, generation: 0)
        let admitted = position.turn(to: 110, pageCount: Self.pageCount)
        let tries = (0..<ReaderPosition.retryLimit).map({ _ in position.pagerSettled(shown: 106, generation: 0) })
        #expect(admitted == .drive(page: 110, generation: 0))
        #expect(tries == Array(repeating: .drive(page: 110, generation: 0), count: ReaderPosition.retryLimit))
    }

    /// The reader's own scroll decides the page, so a miss after it is a new one.
    @Test(arguments: [ScrollPhase.tracking, .interacting, .decelerating])
    func theReadersOwnScrollStartsTheCountOver(phase: ScrollPhase) {
        var position = position()
        _ = position.turn(to: 107, pageCount: Self.pageCount)
        _ = position.pagerSettled(shown: 106, generation: 0)
        _ = position.pagerPhaseChanged(to: PagerMotion(phase), generation: 0)
        _ = position.pagerPhaseChanged(to: .idle, generation: 0)
        _ = position.pagerSettled(shown: 103, generation: 0)
        _ = position.turn(to: 104, pageCount: Self.pageCount)
        let tries = (0..<ReaderPosition.retryLimit).map({ _ in position.pagerSettled(shown: 103, generation: 0) })
        #expect(tries == Array(repeating: .drive(page: 104, generation: 0), count: ReaderPosition.retryLimit))
    }

    /// A turn's own retries keep their count: the pager animating to the turn's page is no new turn.
    @Test
    func aProgrammaticScrollKeepsTheCount() {
        var position = position()
        _ = position.turn(to: 107, pageCount: Self.pageCount)
        let first = position.pagerSettled(shown: 106, generation: 0)
        _ = position.pagerPhaseChanged(to: .animating, generation: 0)
        _ = position.pagerPhaseChanged(to: .idle, generation: 0)
        let second = position.pagerSettled(shown: 106, generation: 0)
        let third = position.pagerSettled(shown: 106, generation: 0)
        let drive = PagerCommand.drive(page: 107, generation: 0)
        #expect([first, second, third] == [drive, drive, nil])
        #expect(position.page == 106)
    }

    // MARK: Stale generations (WR-01)

    /// The old pager's animation, reported after it was torn down, does not hold the new pager's turns.
    @Test
    func aStaleAnimationHoldsNoTurn() {
        var position = position()
        _ = position.pagerRebuilt()
        let stale = position.pagerPhaseChanged(to: .animating, generation: 0)
        let admitted = position.turn(to: 107, pageCount: Self.pageCount)
        #expect(stale == nil)
        #expect(position.motion == .idle)
        #expect(admitted == .drive(page: 107, generation: 1))
    }

    /// The old pager's rest sends no turn held for it: none is left after the rebuild.
    @Test
    func aStaleRestSendsNothing() {
        var position = position()
        _ = position.pagerPhaseChanged(to: .animating, generation: 0)
        _ = position.turn(to: 107, pageCount: Self.pageCount)
        _ = position.pagerRebuilt()
        let before = position
        let stale = position.pagerPhaseChanged(to: .idle, generation: 0)
        #expect(stale == nil)
        #expect(position == before)
    }

    /// The page the old pager showed at rest is no page of the new pager's.
    @Test
    func aStaleObservationChangesNothing() {
        var position = position(on: 107)
        _ = position.pagerRebuilt()
        let before = position
        let stale = position.pagerSettled(shown: 3, generation: 0)
        #expect(stale == nil)
        #expect(position == before)
        #expect(position.page == 107)
    }

    /// A check the old pager scheduled after a turn neither sends the new turn again nor spends its count.
    @Test
    func aStaleRetryChangesNothing() {
        var position = position()
        _ = position.turn(to: 107, pageCount: Self.pageCount)
        _ = position.pagerRebuilt()
        _ = position.turn(to: 110, pageCount: Self.pageCount)
        let before = position
        let stale = position.pagerSettled(shown: 106, generation: 0)
        #expect(stale == nil)
        #expect(position == before)
        let tries = (0..<ReaderPosition.retryLimit).map({ _ in position.pagerSettled(shown: 107, generation: 1) })
        #expect(tries == Array(repeating: .drive(page: 110, generation: 1), count: ReaderPosition.retryLimit))
    }

    // MARK: Rebuilds and placement

    @Test
    func aRebuildFromAPendingTurnPlacesTheNewPagerOnIt() {
        var position = position()
        _ = position.turn(to: 120, pageCount: Self.pageCount)
        let placement = position.pagerRebuilt()
        #expect(position.generation == 1)
        #expect(position.request == nil)
        #expect(position.page == 120)
        #expect(placement == .place(page: 120, generation: 1))
        #expect(position.issued?.command == placement)
    }

    @Test
    func aRebuildAtRestPlacesTheNewPagerOnThePage() {
        var position = position()
        let placement = position.pagerRebuilt()
        let again = position.pagerRebuilt()
        #expect(placement == .place(page: 106, generation: 1))
        #expect(again == .place(page: 106, generation: 2))
        #expect(position.page == 106)
    }

    /// The first pager is built once the reading area is measured, placed on the resume page.
    @Test
    func theResumePageIsPlacedOnceTheAreaIsMeasured() {
        let position = ReaderPosition(page: 42)
        #expect(position.page == 42)
        #expect(position.generation == 0)
        #expect(position.request == nil)
        #expect(position.issued == nil)
        #expect(position.placement == .place(page: 42, generation: 0))
        #expect(ReaderPosition(page: 0).page == 1)
    }

    // MARK: The page the reader names

    /// The reader's own scroll ends with no turn under way, and the page it shows is committed.
    @Test
    func aDragCommitsThePageItShows() {
        var position = position()
        _ = position.pagerPhaseChanged(to: .scrolling, generation: 0)
        let whileScrolling = position.pagerSettled(shown: 104, generation: 0)
        _ = position.pagerPhaseChanged(to: .idle, generation: 0)
        let atRest = position.pagerSettled(shown: 104, generation: 0)
        #expect(whileScrolling == nil)
        #expect(atRest == nil)
        #expect(position.page == 104)
        #expect(position.displayedPage == 104)
    }

    @Test
    func theReaderNamesTheTurnUnderWayOrThePage() {
        var position = position()
        #expect(position.displayedPage == 106)
        _ = position.turn(to: 150, pageCount: Self.pageCount)
        #expect(position.displayedPage == 150)
        #expect(position.page == 106)
        _ = position.pagerSettled(shown: 150, generation: 0)
        #expect(position.displayedPage == 150)
        #expect(position.page == 150)
    }

    @Test
    func aTurnIsClampedToTheGalleryAndATurnToTheNamedPageSendsNothing() {
        var position = position(on: 3)
        let pastTheEnd = position.turn(to: 12, pageCount: 10)
        let again = position.turn(to: 10, pageCount: 10)
        let beforeTheStart = position.turn(to: -4, pageCount: 10)
        #expect(pastTheEnd == .drive(page: 10, generation: 0))
        #expect(again == nil)
        #expect(beforeTheStart == .drive(page: 1, generation: 0))
    }

    /// Two equal commands in a row are two commands for the view to carry out.
    @Test
    func everyCommandIsIssuedOnce() {
        var position = position()
        _ = position.turn(to: 107, pageCount: Self.pageCount)
        let first = position.issued
        _ = position.pagerSettled(shown: 106, generation: 0)
        let second = position.issued
        #expect(first?.command == second?.command)
        #expect(first != second)
    }
}
