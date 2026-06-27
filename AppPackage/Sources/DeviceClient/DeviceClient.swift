import SwiftUI
import Dependencies
import Utilities

public struct DeviceClient: Sendable {
    public let isPad: @Sendable () async -> Bool
    public let absWindowW: @MainActor @Sendable () -> Double
    public let absWindowH: @MainActor @Sendable () -> Double
    public let touchPoint: @MainActor @Sendable () -> CGPoint?
}

extension DeviceClient {
    public static let live: Self = .init(
        isPad: {
            await MainActor.run {
                DeviceUtil.isPad
            }
        },
        absWindowW: {
            DeviceUtil.absWindowW
        },
        absWindowH: {
            DeviceUtil.absWindowH
        },
        touchPoint: {
            TouchHandler.shared.currentPoint
        }
    )
}

// MARK: API
public enum DeviceClientKey: DependencyKey {
    public static let liveValue = DeviceClient.live
    public static let previewValue = DeviceClient.noop
    public static let testValue = DeviceClient.unimplemented
}

extension DependencyValues {
    public var deviceClient: DeviceClient {
        get { self[DeviceClientKey.self] }
        set { self[DeviceClientKey.self] = newValue }
    }
}

// MARK: Test
extension DeviceClient {
    public static let noop: Self = .init(
        isPad: { false },
        absWindowW: { .zero },
        absWindowH: { .zero },
        touchPoint: { .zero }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        isPad: IssueReporting.unimplemented(placeholder: placeholder()),
        absWindowW: IssueReporting.unimplemented(placeholder: placeholder()),
        absWindowH: IssueReporting.unimplemented(placeholder: placeholder()),
        touchPoint: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
