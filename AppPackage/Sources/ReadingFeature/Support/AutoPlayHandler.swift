import Clocks
import Dependencies
import Observation

@Observable
@MainActor
final class AutoPlayHandler {
    /// The interval auto-play turns pages at, `.off` while it does not. Every assignment restarts the ticking, so the
    /// toolbar's menu and the reader's stops only assign it.
    ///
    /// The toolbar's menu binds it as `$handler.policy`. A closure `Binding` is a new value on every evaluation of the
    /// reader's body, and every page auto-play turns redraws the toolbar's page indicator, so SwiftUI gave the menu's
    /// toolbar item a new `UIMenu` on each turn, and a tap on the open menu could land on a replaced row and be lost
    /// (measured 2026-10-12 on iOS 27: a new menu on each title change with a closure binding, the same menu with
    /// this binding).
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
