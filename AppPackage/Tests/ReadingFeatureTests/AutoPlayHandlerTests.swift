import AppModels
import Clocks
import ComposableArchitecture
import Dependencies
import Foundation
@testable import ReadingFeature
import Sharing
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

    // Each tick turns one position on, and the tick that reaches the last position stops auto-play.
    @Test
    func aTickTurnsOnePositionAndStopsAtTheLast() {
        let ticks = [3, 7, 8, 9].map({ AutoPlayHandler.tick(from: $0, count: 10) })

        #expect(ticks.map(\.target) == [4, 8, 9, 9])
        #expect(ticks.map(\.stops) == [false, false, true, true])
    }

    // The reader sends a tick's position as its one turn intent, which sends the pager to its page.
    @Test
    func aTickIsSentAsTheOneTurnIntent() async {
        var gallery = Gallery.preview
        gallery.pageCount = 10
        var state = withDependencies {
            $0.defaultAppStorage = UserDefaults.inMemory
        } operation: {
            ReadingReducer.State(gallery: gallery)
        }
        state.readingProgress = 3
        let store = TestStore(initialState: state, reducer: ReadingReducer.init)
        let handler = PageHandler()
        let position = handler.mapToPager(index: 3, setting: state.setting, isLandscape: false)
        let tick = AutoPlayHandler.tick(from: position, count: 10)
        let page = handler.mapFromPager(index: tick.target, pageCount: 10, setting: state.setting, isLandscape: false)

        await store.send(.turn(toPage: page)) {
            _ = $0.position.turn(to: 4, pageCount: 10)
        }
        #expect(store.state.position.issued?.command == .drive(page: 4, generation: 0))
        await store.finish()
    }
}
