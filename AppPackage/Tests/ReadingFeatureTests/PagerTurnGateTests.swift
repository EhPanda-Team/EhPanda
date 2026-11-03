@testable import ReadingFeature
import SwiftUI
import Testing

// Pins the rule that keeps the horizontal pager on the index: a turn that arrives while the pager animates to the
// previous one is held and sent once the pager is at rest, because the paging ScrollView can drop a position handed
// to it mid-animation and come to rest short of it (see `PagerTurnGate`).
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
}
