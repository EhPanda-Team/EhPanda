import AppTools
import Dependencies
import UIKit

public struct DeviceClient: Sendable {
    public let deviceType: @MainActor @Sendable () -> DeviceType
    public let isLandscape: @MainActor @Sendable () -> Bool

    public init(
        deviceType: @escaping @MainActor @Sendable () -> DeviceType,
        isLandscape: @escaping @MainActor @Sendable () -> Bool
    ) {
        self.deviceType = deviceType
        self.isLandscape = isLandscape
    }
}

extension DeviceClient {
    public static let live: Self = .init(
        deviceType: {
            #if os(macOS)
            .mac
            #elseif os(tvOS)
            .tv
            #elseif os(watchOS)
            .watch
            #elseif os(visionOS)
            .vision
            #elseif canImport(UIKit)
            .init(idiom: UIDevice.current.userInterfaceIdiom)
            #endif
        },
        isLandscape: {
            UIApplication.shared.connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .first(where: { $0.activationState == .foregroundActive })?
                .effectiveGeometry.interfaceOrientation.isLandscape ?? false
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
        deviceType: { .phone },
        isLandscape: { false }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        deviceType: IssueReporting.unimplemented(placeholder: placeholder()),
        isLandscape: IssueReporting.unimplemented(placeholder: false)
    )
}
