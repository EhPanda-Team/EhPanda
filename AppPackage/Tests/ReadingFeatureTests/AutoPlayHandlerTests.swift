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
        handler.policy = .sec2

        await clock.advance(by: .seconds(1))
        let beforeTheInterval = handler.tickCount
        await clock.advance(by: .seconds(1))
        let afterOneInterval = handler.tickCount
        await clock.advance(by: .seconds(6))
        let afterFourIntervals = handler.tickCount

        #expect(beforeTheInterval == 0)
        #expect(afterOneInterval == 1)
        #expect(afterFourIntervals == 4)
    }

    @Test
    func changingThePolicyStartsItsIntervalOver() async {
        let handler = makeHandler()
        handler.policy = .sec1
        await clock.advance(by: .seconds(1))
        let underTheFirstPolicy = handler.tickCount

        handler.policy = .sec5
        await clock.advance(by: .seconds(4))
        let beforeTheNewInterval = handler.tickCount
        await clock.advance(by: .seconds(1))
        let afterTheNewInterval = handler.tickCount

        #expect(underTheFirstPolicy == 1)
        #expect(beforeTheNewInterval == 1)
        #expect(afterTheNewInterval == 2)
    }

    // The reader turns auto-play off this way from the tick that reaches the last page, when it
    // disappears, and when it opens a sheet or the slider's preview.
    @Test
    func turningAutoPlayOffStopsTheTicks() async {
        let handler = makeHandler()
        handler.policy = .sec1
        await clock.advance(by: .seconds(1))
        let whileOn = handler.tickCount

        handler.policy = .off
        await clock.advance(by: .seconds(10))

        #expect(whileOn == 1)
        #expect(handler.tickCount == 1)
    }

    // The ticking holds the handler only while a tick counts, so releasing the reader's state
    // releases the handler while auto-play runs, and the handler's deinit stops the ticking.
    @Test
    func aRunningPolicyLetsTheHandlerGo() async {
        var handler: AutoPlayHandler? = makeHandler()
        weak let released = handler
        handler?.policy = .sec1
        await clock.advance(by: .seconds(1))
        let whileHeld = released?.tickCount

        handler = nil

        #expect(whileHeld == 1)
        #expect(released == nil)
    }
}
