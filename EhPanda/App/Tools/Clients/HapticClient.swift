//
//  HapticClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/02.
//

import SwiftUI
import ComposableArchitecture

struct HapticClient {
    let generateFeedback: (UIImpactFeedbackGenerator.FeedbackStyle) -> Effect<Never, Never>
    let generateNotificationFeedback: (UINotificationFeedbackGenerator.FeedbackType) -> Effect<Never, Never>
}

extension HapticClient {
    static let live: Self = .init(
        generateFeedback: { style in
            .fireAndForget {
                HapticUtil.generateFeedback(style: style)
            }
        },
        generateNotificationFeedback: { style in
            .fireAndForget {
                HapticUtil.generateNotificationFeedback(style: style)
            }
        }
    )
}
// MARK: Test
#if DEBUG
extension HapticClient {
    static let failing: Self = .init(
        generateFeedback: { .failing("\(Self.self).generateFeedback(\($0)) is unimplemented") },
        generateNotificationFeedback: { .failing("\(Self.self).generateNotificationFeedback(\($0)) is unimplemented") }
    )
}
#endif
extension HapticClient {
    static let noop: Self = .init(
        generateFeedback: { _ in .none },
        generateNotificationFeedback: { _ in .none }
    )
}
