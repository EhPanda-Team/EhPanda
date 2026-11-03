@testable import ReadingFeature
import SwiftUI
import Testing

// Pins the rules that keep the horizontal pager on the index, because the paging ScrollView can drop a position handed
// to it while it moves or comes to rest, and stay short of it (see `PagerTurnGate`): a turn that arrives while the
// pager animates to the previous one is held and sent once the pager is at rest, and a pager at rest on another page
// than the index is sent to the index again.
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

    @Test
    func aPagerBuiltAnewClearsAGateLeftMidAnimation() {
        var gate = PagerTurnGate()
        _ = gate.phaseChanged(to: .animating)
        let held = gate.admitsTurn()
        // The new pager's first report is `.idle`: the held turn is sent to the index, and turns pass again.
        let sendsOnAppearance = gate.phaseChanged(to: .idle)
        let admitted = gate.admitsTurn()
        #expect(!held)
        #expect(sendsOnAppearance)
        #expect(admitted)
    }

    @Test
    func aPagerAtRestOnAnotherPageIsSentToTheIndexAgain() {
        var gate = PagerTurnGate()
        _ = gate.phaseChanged(to: .animating)
        _ = gate.phaseChanged(to: .idle)
        let corrects = gate.needsCorrection(shown: 106, index: 107)
        #expect(corrects)
    }

    @Test
    func aPagerAtRestOnTheIndexIsLeftAlone() {
        var gate = PagerTurnGate()
        let onTheIndex = gate.needsCorrection(shown: 107, index: 107)
        let noSinglePage = gate.needsCorrection(shown: nil, index: 107)
        #expect(!onTheIndex)
        #expect(!noSinglePage)
    }

    @Test(arguments: [ScrollPhase.animating, .tracking, .interacting, .decelerating])
    func aMovingPagerIsNotCorrected(phase: ScrollPhase) {
        var gate = PagerTurnGate()
        _ = gate.phaseChanged(to: phase)
        let corrects = gate.needsCorrection(shown: 106, index: 107)
        #expect(!corrects)
    }

    @Test
    func aPageThePagerKeepsMissingIsGivenUpUntilItLandsAgain() {
        var gate = PagerTurnGate()
        let tries = (0..<PagerTurnGate.correctionLimit).map({ _ in gate.needsCorrection(shown: 106, index: 107) })
        let beyondTheLimit = gate.needsCorrection(shown: 106, index: 107)
        #expect(tries == Array(repeating: true, count: PagerTurnGate.correctionLimit))
        #expect(!beyondTheLimit)

        // Landing on the index starts the count over.
        _ = gate.needsCorrection(shown: 107, index: 107)
        let afterLanding = gate.needsCorrection(shown: 107, index: 108)
        #expect(afterLanding)
    }
}
