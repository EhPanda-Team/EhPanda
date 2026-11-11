import Foundation
import Synchronization
import Testing

/// The accounting behind every wait in this target that only bounds a hang (``ProgressDeadline``): time the
/// process was running is spent, time it was not given is not.
@Suite
struct ProgressDeadlineTests {
    /// A clock the case moves by hand, so no case here depends on how fast the host runs it.
    private final class ManualClock: Sendable {
        private let origin = ContinuousClock.now
        private let elapsed = Mutex(Duration.zero)

        var now: ContinuousClock.Instant { origin.advanced(by: elapsed.withLock({ $0 })) }

        func pass(_ duration: Duration) {
            elapsed.withLock({ $0 += duration })
        }
    }

    @Test
    func lookingOftenSpendsTheBudgetInTheTimeItNames() {
        let clock = ManualClock()
        var deadline = ProgressDeadline(.seconds(30), now: { clock.now })
        var looks = 0
        while deadline.hasTimeLeft() {
            clock.pass(.milliseconds(100))
            looks += 1
        }
        #expect(looks == 300)
    }

    @Test
    func aGapBeyondTheStallCapSpendsOnlyTheCap() {
        let clock = ManualClock()
        var deadline = ProgressDeadline(.seconds(30), now: { clock.now })
        clock.pass(.seconds(150))
        let afterTheFirstStall = deadline.hasTimeLeft()
        #expect(afterTheFirstStall)
        clock.pass(.seconds(270))
        let afterTheSecondStall = deadline.hasTimeLeft()
        #expect(afterTheSecondStall)
        var looks = 2
        while deadline.hasTimeLeft() {
            clock.pass(.seconds(10))
            looks += 1
        }
        // Two stalls of minutes cost one cap each, and every gap after them costs one cap: thirty looks in all.
        #expect(looks == 30)
    }

    @Test
    func aGapUnderTheStallCapSpendsItsWholeLength() {
        let clock = ManualClock()
        var deadline = ProgressDeadline(.seconds(3), now: { clock.now })
        clock.pass(.milliseconds(900))
        let afterTheFirstGap = deadline.hasTimeLeft()
        #expect(afterTheFirstGap)
        clock.pass(.milliseconds(900))
        let afterTheSecondGap = deadline.hasTimeLeft()
        #expect(afterTheSecondGap)
        clock.pass(.milliseconds(900))
        let afterTheThirdGap = deadline.hasTimeLeft()
        #expect(afterTheThirdGap)
        clock.pass(.milliseconds(900))
        let afterTheFourthGap = deadline.hasTimeLeft()
        #expect(!afterTheFourthGap)
    }

    @Test
    func aWaitThatNothingEndsStillExpires() async throws {
        let started = ContinuousClock.now
        try await ProgressDeadline.sleep(for: .milliseconds(300))
        #expect(started.duration(to: .now) >= .milliseconds(300))
    }
}
