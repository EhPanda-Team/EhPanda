public import AppTools
public import Dependencies
import UIKit

public struct DeviceClient: Sendable {
    public let deviceType: @MainActor @Sendable () -> DeviceType
    /// The interface orientation, or `nil` when no foreground-active scene can answer.
    ///
    /// `nil` is a real state, not an edge case to smooth over: it is what a launch-time or
    /// backgrounded caller sees, and a caller that records the answer needs to tell "portrait"
    /// apart from "no answer". Layout never reads this: an orientation says how the interface is
    /// rotated, not how much room a view has, so views decide from their measured size instead.
    public let interfaceOrientation: @MainActor @Sendable () -> InterfaceOrientation?

    public init(
        deviceType: @escaping @MainActor @Sendable () -> DeviceType,
        interfaceOrientation: @escaping @MainActor @Sendable () -> InterfaceOrientation?
    ) {
        self.deviceType = deviceType
        self.interfaceOrientation = interfaceOrientation
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
        interfaceOrientation: {
            UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
                .flatMap({ InterfaceOrientation($0.effectiveGeometry.interfaceOrientation) })
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
        interfaceOrientation: { .portrait }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        deviceType: IssueReporting.unimplemented(placeholder: placeholder()),
        interfaceOrientation: IssueReporting.unimplemented(placeholder: InterfaceOrientation?.none)
    )
}
