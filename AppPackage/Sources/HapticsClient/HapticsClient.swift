import SwiftUI
import AudioToolbox
import ComposableArchitecture

public struct HapticsClient: Sendable {
    public let generateFeedback: @MainActor @Sendable (UIImpactFeedbackGenerator.FeedbackStyle) -> Void
    public let generateNotificationFeedback: @MainActor @Sendable (UINotificationFeedbackGenerator.FeedbackType) -> Void
}

extension HapticsClient {
    public static let live: Self = .init(
        generateFeedback: { style in
            guard !isLegacyTapticEngine else {
                generateLegacyFeedback()
                return
            }
            UIImpactFeedbackGenerator(style: style).impactOccurred()
        },
        generateNotificationFeedback: { style in
            guard !isLegacyTapticEngine else {
                generateLegacyFeedback()
                return
            }
            UINotificationFeedbackGenerator().notificationOccurred(style)
        }
    )

    private static func generateLegacyFeedback() {
        AudioServicesPlaySystemSound(1519)
        AudioServicesPlaySystemSound(1520)
        AudioServicesPlaySystemSound(1521)
        AudioServicesPlaySystemSound(kSystemSoundID_Vibrate)
    }

    private static let isLegacyTapticEngine: Bool = {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return ["iPhone8,1", "iPhone8,2"].contains(identifier)
    }()
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
