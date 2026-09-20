import Clocks
import Dependencies
@testable import ReadingFeature
import Testing

// Auto-play is one of the ways the reader's page changes without the user touching it. The handler
// measures its interval on the injected clock, so every case here drives a `TestClock` and nothing
// sleeps. Each case that expects silence makes the handler tick first: a clock no sleeper was ever
// registered on stays silent whatever the handler does, and that would pass vacuously.
@MainActor
@Suite
struct AutoPlayHandlerTests {
    /// What the tick closure counts into. A reference, so the closure the handler keeps and the
    /// case that reads the count share one value.
    private final class Ticks {
        var count = 0
    }

    private let clock = TestClock()

    private func makeHandler() -> AutoPlayHandler {
        withDependencies {
            $0.continuousClock = clock
        } operation: {
            AutoPlayHandler()
        }
    }

    @Test
    func aPolicyTicksOncePerInterval() async {
        let handler = makeHandler()
        let ticks = Ticks()
        handler.setPolicy(.sec2, updatePageAction: { ticks.count += 1 })

        await clock.advance(by: .seconds(1))
        let beforeTheInterval = ticks.count
        await clock.advance(by: .seconds(1))
        let afterOneInterval = ticks.count
        await clock.advance(by: .seconds(6))
        let afterFourIntervals = ticks.count

        #expect(beforeTheInterval == 0)
        #expect(afterOneInterval == 1)
        #expect(afterFourIntervals == 4)
    }

    @Test
    func changingThePolicyStartsItsIntervalOver() async {
        let handler = makeHandler()
        let ticks = Ticks()
        handler.setPolicy(.sec1, updatePageAction: { ticks.count += 1 })
        await clock.advance(by: .seconds(1))
        let underTheFirstPolicy = ticks.count

        handler.setPolicy(.sec5, updatePageAction: { ticks.count += 1 })
        await clock.advance(by: .seconds(4))
        let beforeTheNewInterval = ticks.count
        await clock.advance(by: .seconds(1))
        let afterTheNewInterval = ticks.count

        #expect(underTheFirstPolicy == 1)
        #expect(beforeTheNewInterval == 1)
        #expect(afterTheNewInterval == 2)
        #expect(handler.policy == .sec5)
    }

    @Test
    func turningAutoPlayOffStopsTheTicks() async {
        let handler = makeHandler()
        let ticks = Ticks()
        handler.setPolicy(.sec1, updatePageAction: { ticks.count += 1 })
        await clock.advance(by: .seconds(1))
        let whileOn = ticks.count

        handler.setPolicy(.off, updatePageAction: { ticks.count += 1 })
        await clock.advance(by: .seconds(10))

        #expect(whileOn == 1)
        #expect(ticks.count == 1)
        #expect(handler.policy == .off)
    }

    // The reader turns auto-play off from inside the tick that reaches the last page.
    @Test
    func aTickMayTurnAutoPlayOff() async {
        let handler = makeHandler()
        let ticks = Ticks()
        handler.setPolicy(.sec1) {
            ticks.count += 1
            if ticks.count == 2 {
                handler.setPolicy(.off, updatePageAction: {})
            }
        }

        await clock.advance(by: .seconds(10))

        #expect(ticks.count == 2)
    }

    // The reader invalidates the handler when it disappears, so no page of a reader nobody is
    // looking at gets turned.
    @Test
    func invalidatingStopsTheTicks() async {
        let handler = makeHandler()
        let ticks = Ticks()
        handler.setPolicy(.sec1, updatePageAction: { ticks.count += 1 })
        await clock.advance(by: .seconds(1))
        let whileValid = ticks.count

        handler.invalidate()
        await clock.advance(by: .seconds(10))

        #expect(whileValid == 1)
        #expect(ticks.count == 1)
    }
}
