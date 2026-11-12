import Clocks
import Dependencies
import Observation

@Observable
@MainActor
final class AutoPlayHandler {
    /// The interval auto-play turns pages at, `.off` while it does not. Every assignment restarts the ticking, so the
    /// toolbar's menu and the reader's stops only assign it.
    ///
    /// The toolbar's menu is a view of its own whose one input is this handler, and it binds `$handler.policy`. Every
    /// page turn re-evaluates the toolbar, which is handed the page's title; a menu built inline in the toolbar, as
    /// before, could be given a new `UIMenu` on such a turn, and a tap on the open menu could land on a replaced row
    /// and be lost. A closure binding did so on every turn (measured 2026-10-12); this binding still did so in some
    /// launches (measured 2026-11-03, the item IDs of the open menu changing on each turn), both on iOS 27.
    var policy = AutoPlayPolicy.off {
        didSet { restartTicking() }
    }
    /// The ticks of the running policy. The reader turns a page on each change, so the ticking holds nothing of the
    /// view.
    private(set) var tickCount = 0
    // The interval is measured on the injected clock rather than by a `Timer`, so a test can drive
    // the ticks with a `TestClock` instead of waiting for them.
    @ObservationIgnored
    @Dependency(\.continuousClock) private var clock
    @ObservationIgnored
    private var ticking: Task<Void, Never>?

    /// The pager position one tick turns to from `position`, among `count` positions, and whether auto-play stops
    /// there. The tick that reaches the last position stops it, rather than ticking against the end for the rest of the
    /// interval. The reader sends the turn as `ReadingReducer.Action.turn(toPage:)`, its one turn intent.
    static func tick(from position: Int, count: Int) -> (target: Int, stops: Bool) {
        let last = max(count - 1, 0)
        let target = min(max(position + 1, 0), last)
        return (target: target, stops: target >= last)
    }

    isolated deinit {
        ticking?.cancel()
    }

    private func restartTicking() {
        ticking?.cancel()
        guard policy.rawValue > 0 else { return }
        ticking = Task { [weak self, clock, interval = policy.rawValue] in
            for await _ in clock.timer(interval: .seconds(interval)) {
                // A tick already due when the policy changed still resumes this loop once.
                guard !Task.isCancelled, let self else { return }
                tickCount += 1
            }
        }
    }
}
