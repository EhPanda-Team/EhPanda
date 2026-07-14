import SwiftUI
import ComposableArchitecture

public struct HapticsClient: Sendable {
    public let generateFeedback: @MainActor @Sendable (UIImpactFeedbackGenerator.FeedbackStyle) -> Void
    public let generateNotificationFeedback: @MainActor @Sendable (UINotificationFeedbackGenerator.FeedbackType) -> Void
}

extension HapticsClient {
    public static let live: Self = .init(
        generateFeedback: { UIImpactFeedbackGenerator(style: $0).impactOccurred() },
        generateNotificationFeedback: { UINotificationFeedbackGenerator().notificationOccurred($0) }
    )
}

// MARK: API
public enum HapticsClientKey: DependencyKey {
    public static let liveValue = HapticsClient.live
    public static let previewValue = HapticsClient.noop
    public static let testValue = HapticsClient.unimplemented
}

extension DependencyValues {
    public var hapticsClient: HapticsClient {
        get { self[HapticsClientKey.self] }
        set { self[HapticsClientKey.self] = newValue }
    }
}

// MARK: Test
extension HapticsClient {
    public static let noop: Self = .init(
        generateFeedback: { _ in },
        generateNotificationFeedback: { _ in }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        generateFeedback: IssueReporting.unimplemented(placeholder: placeholder()),
        generateNotificationFeedback: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
