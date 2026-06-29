import SwiftUI
import AppModels
import Observation

@Observable
@MainActor
final class AutoPlayHandler {
    var policy: AutoPlayPolicy = .off
    @ObservationIgnored
    private var timer: Timer?

    isolated deinit {
        invalidate()
    }

    func invalidate() {
        timer?.invalidate()
    }

    func setPolicy(_ policy: AutoPlayPolicy, updatePageAction: @MainActor @escaping () -> Void) {
        self.policy = policy
        timer?.invalidate()
        let timeInterval = TimeInterval(policy.rawValue)
        if timeInterval > 0 {
            timer = .scheduledTimer(
                withTimeInterval: timeInterval, repeats: true,
                block: { _ in
                    Task { @MainActor in
                        updatePageAction()
                    }
                }
            )
        }
    }
}
