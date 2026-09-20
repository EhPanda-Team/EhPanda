import Clocks
import Dependencies
import Observation

@Observable
@MainActor
final class AutoPlayHandler {
    var policy: AutoPlayPolicy = .off
    // The interval is measured on the injected clock rather than by a `Timer`, so a test can drive
    // the ticks with a `TestClock` instead of waiting for them.
    @ObservationIgnored
    @Dependency(\.continuousClock) private var clock
    @ObservationIgnored
    private var ticking: Task<Void, Never>?

    isolated deinit {
        invalidate()
    }

    func invalidate() {
        ticking?.cancel()
    }

    func setPolicy(_ policy: AutoPlayPolicy, updatePageAction: @MainActor @escaping () -> Void) {
        self.policy = policy
        ticking?.cancel()
        guard policy.rawValue > 0 else { return }
        ticking = Task { [clock] in
            for await _ in clock.timer(interval: .seconds(policy.rawValue)) {
                // A tick already due when the policy changed still resumes this loop once.
                guard !Task.isCancelled else { return }
                updatePageAction()
            }
        }
    }
}
