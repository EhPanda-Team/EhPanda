import AppTools
import Dependencies

public struct DeviceClient: Sendable {
    public let deviceType: @MainActor @Sendable () -> DeviceType

    public init(
        deviceType: @escaping @MainActor @Sendable () -> DeviceType
    ) {
        self.deviceType = deviceType
    }
}

extension DeviceClient {
    public static let live: Self = .init(
        deviceType: {
            DeviceType.current
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
        deviceType: { .phone }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        deviceType: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
