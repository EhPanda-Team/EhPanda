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
