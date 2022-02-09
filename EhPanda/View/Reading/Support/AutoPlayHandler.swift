//
//  AutoPlayHandler.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/09.
//

import SwiftUI

final class AutoPlayHandler: ObservableObject {
    @Published var policy: AutoPlayPolicy = .off
    private var timer: Timer?

    deinit {
        invalidate()
    }

    func invalidate() {
        Logger.info("invalidate")
        timer?.invalidate()
    }

    func setPolicy(_ policy: AutoPlayPolicy, updatePageAction: @escaping () -> Void) {
        Logger.info("setPolicy", context: ["policy": policy])
        self.policy = policy
        timer?.invalidate()
        let timeInterval = TimeInterval(policy.rawValue)
        if timeInterval > 0 {
            timer = .scheduledTimer(
                withTimeInterval: timeInterval, repeats: true,
                block: { _ in updatePageAction() }
            )
        }
    }
}
