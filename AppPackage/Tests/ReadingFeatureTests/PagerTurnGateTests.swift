@testable import ReadingFeature
import SwiftUI
import Testing

// Pins the rules that keep the horizontal pager on the index, because the paging ScrollView can drop a position handed
// to it while it moves or comes to rest, and stay short of it (see `PagerTurnGate`): a turn that arrives while the
// pager animates to the previous one is held and sent once the pager is at rest, and a pager at rest on another page
// than the index is sent to the index again, until the index follows the page on screen instead.
@Suite
struct PagerTurnGateTests {
    @Test
    func aTurnFromRestIsSentAtOnce() {
        var gate = PagerTurnGate()
        let admitted = gate.admitsTurn()
        #expect(admitted)
        #expect(!gate.holdsTurn)
    }

    @Test
    func aTurnWhileThePagerAnimatesIsHeldAndSentAtRest() {
        var gate = PagerTurnGate()
        let first = gate.admitsTurn()
        let sendsOnAnimating = gate.phaseChanged(to: .animating)
        let second = gate.admitsTurn()
        let third = gate.admitsTurn()
        #expect(first)
        #expect(!sendsOnAnimating)
        #expect(!second)
        #expect(!third)
        #expect(gate.holdsTurn)

        let sendsAtRest = gate.phaseChanged(to: .idle)
        #expect(sendsAtRest)
        #expect(!gate.holdsTurn)
        let afterRest = gate.admitsTurn()
        #expect(afterRest)
    }

    @Test
    func restWithNothingHeldSendsNothing() {
        var gate = PagerTurnGate()
        let sendsOnAnimating = gate.phaseChanged(to: .animating)
        let sendsAtRest = gate.phaseChanged(to: .idle)
        #expect(!sendsOnAnimating)
        #expect(!sendsAtRest)
    }

    @Test(arguments: [ScrollPhase.tracking, .interacting, .decelerating])
    func theReadersOwnScrollDropsTheHeldTurn(phase: ScrollPhase) {
        var gate = PagerTurnGate()
        _ = gate.phaseChanged(to: .animating)
        let held = gate.admitsTurn()
        let sendsOnTakeOver = gate.phaseChanged(to: phase)
        #expect(!held)
        #expect(!sendsOnTakeOver)
        #expect(!gate.holdsTurn)

        let admitted = gate.admitsTurn()
        let sendsAtRest = gate.phaseChanged(to: .idle)
        #expect(admitted)
        #expect(!sendsAtRest)
    }

    /// A pager built anew, after a forced refresh or a change of direction, starts at rest and reports no phase until
    /// it moves. A gate the old pager left mid-animation must not go on holding the new pager's turns.
    @Test
    func aPagerBuiltAnewAdmitsTurnsAGateLeftMidAnimationHeld() {
        var gate = PagerTurnGate()
        _ = gate.phaseChanged(to: .animating)
        let held = gate.admitsTurn()
        gate.pagerRebuilt()
        let admitted = gate.admitsTurn()
        #expect(!held)
        #expect(admitted)
        #expect(!gate.holdsTurn)
    }

    /// The new pager is placed on the index, which the held turn has already moved, so its first rest sends nothing.
    @Test
    func aPagerBuiltAnewDropsTheTurnHeldForTheOldOne() {
        var gate = PagerTurnGate()
        _ = gate.phaseChanged(to: .animating)
        _ = gate.admitsTurn()
        gate.pagerRebuilt()
        let sendsAtFirstRest = gate.phaseChanged(to: .idle)
        #expect(!sendsAtFirstRest)
    }

    /// Without a phase report from the new pager, the page it shows is still checked against the index.
    @Test
    func aPagerBuiltAnewIsCheckedAtRest() {
        var gate = PagerTurnGate()
        _ = gate.phaseChanged(to: .animating)
        gate.pagerRebuilt()
        let correction = gate.correction(shown: 106, index: 107)
        #expect(correction == .sendAgain)
    }

    @Test
    func aPagerBuiltAnewStartsTheCountOver() {
        var gate = PagerTurnGate()
        _ = gate.correction(shown: 106, index: 107)
        gate.pagerRebuilt()
        let tries = (0..<PagerTurnGate.correctionLimit).map({ _ in gate.correction(shown: 106, index: 110) })
        #expect(tries == Array(repeating: .sendAgain, count: PagerTurnGate.correctionLimit))
    }

    @Test
    func aPagerAtRestOnAnotherPageIsSentToTheIndexAgain() {
        var gate = PagerTurnGate()
        _ = gate.phaseChanged(to: .animating)
        _ = gate.phaseChanged(to: .idle)
        let correction = gate.correction(shown: 106, index: 107)
        #expect(correction == .sendAgain)
    }

    @Test
    func aPagerAtRestOnTheIndexIsLeftAlone() {
        var gate = PagerTurnGate()
        let onTheIndex = gate.correction(shown: 107, index: 107)
        let noSinglePage = gate.correction(shown: nil, index: 107)
        #expect(onTheIndex == nil)
        #expect(noSinglePage == nil)
    }

    @Test(arguments: [ScrollPhase.animating, .tracking, .interacting, .decelerating])
    func aMovingPagerIsNotCorrected(phase: ScrollPhase) {
        var gate = PagerTurnGate()
        _ = gate.phaseChanged(to: phase)
        let correction = gate.correction(shown: 106, index: 107)
        #expect(correction == nil)
    }

    /// The indicator must never name a page the screen does not show: once the pager has missed the index
    /// `correctionLimit` times in a row, the index follows the page on screen.
    @Test
    func theIndexFollowsTheScreenWhenThePagerKeepsMissingIt() {
        var gate = PagerTurnGate()
        let tries = (0..<PagerTurnGate.correctionLimit).map({ _ in gate.correction(shown: 106, index: 107) })
        let beyondTheLimit = gate.correction(shown: 106, index: 107)
        #expect(tries == Array(repeating: .sendAgain, count: PagerTurnGate.correctionLimit))
        #expect(beyondTheLimit == .followScreen)

        // With the index on the page on screen, the two are in step and the count starts over.
        let inStep = gate.correction(shown: 106, index: 106)
        let nextMiss = gate.correction(shown: 106, index: 110)
        #expect(inStep == nil)
        #expect(nextMiss == .sendAgain)
    }

    @Test
    func landingOnTheIndexStartsTheCountOver() {
        var gate = PagerTurnGate()
        _ = gate.correction(shown: 106, index: 107)
        _ = gate.correction(shown: 107, index: 107)
        let tries = (0..<PagerTurnGate.correctionLimit).map({ _ in gate.correction(shown: 107, index: 108) })
        #expect(tries == Array(repeating: .sendAgain, count: PagerTurnGate.correctionLimit))
    }
}
