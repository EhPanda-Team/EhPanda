//
//  HapticsClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/02.
//

import SwiftUI
import ComposableArchitecture

struct HapticsClient {
    let generateFeedback: (UIImpactFeedbackGenerator.FeedbackStyle) -> EffectTask<Never>
    let generateNotificationFeedback: (UINotificationFeedbackGenerator.FeedbackType) -> EffectTask<Never>
}

extension HapticsClient {
    static let live: Self = .init(
        generateFeedback: { style in
            .fireAndForget {
                HapticsUtil.generateFeedback(style: style)
            }
        },
        generateNotificationFeedback: { style in
            .fireAndForget {
                HapticsUtil.generateNotificationFeedback(style: style)
            }
        }
    )
}

// MARK: API
enum HapticsClientKey: DependencyKey {
    static let liveValue = HapticsClient.live
    static let previewValue = HapticsClient.noop
    static let testValue = HapticsClient.unimplemented
}

extension DependencyValues {
    var hapticsClient: HapticsClient {
        get { self[HapticsClientKey.self] }
        set { self[HapticsClientKey.self] = newValue }
    }
}

// MARK: Test
extension HapticsClient {
    static let noop: Self = .init(
        generateFeedback: { _ in .none },
        generateNotificationFeedback: { _ in .none }
    )

    static let unimplemented: Self = .init(
        generateFeedback: XCTestDynamicOverlay.unimplemented("\(Self.self).generateFeedback"),
        generateNotificationFeedback: XCTestDynamicOverlay.unimplemented("\(Self.self).generateNotificationFeedback")
    )
}
