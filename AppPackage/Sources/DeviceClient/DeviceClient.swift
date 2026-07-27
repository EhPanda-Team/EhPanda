import AppTools
import Dependencies
import UIKit

public struct DeviceClient: Sendable {
    public let deviceType: @MainActor @Sendable () -> DeviceType
    public let isLandscape: @MainActor @Sendable () -> Bool
    /// The interface orientation, or `nil` when no foreground-active scene can answer.
    ///
    /// `nil` is a real state, not an edge case to smooth over: it is what a launch-time or
    /// backgrounded caller sees. ``isLandscape`` collapses it to `false` because a layout decision
    /// has to pick something, but a caller that records the answer rather than laying out with it
    /// needs to tell "portrait" apart from "no answer".
    public let interfaceOrientation: @MainActor @Sendable () -> InterfaceOrientation?

    public init(
        deviceType: @escaping @MainActor @Sendable () -> DeviceType,
        isLandscape: @escaping @MainActor @Sendable () -> Bool,
        interfaceOrientation: @escaping @MainActor @Sendable () -> InterfaceOrientation?
    ) {
        self.deviceType = deviceType
        self.isLandscape = isLandscape
        self.interfaceOrientation = interfaceOrientation
    }
}

extension DeviceClient {
    /// The single place the scene graph is queried, so `isLandscape` and `interfaceOrientation`
    /// cannot drift apart into two different notions of "which way is up".
    @MainActor
    private static func activeInterfaceOrientation() -> InterfaceOrientation? {
        UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
            .flatMap({ InterfaceOrientation($0.effectiveGeometry.interfaceOrientation) })
    }

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
        isLandscape: { activeInterfaceOrientation() == .landscape },
        interfaceOrientation: { activeInterfaceOrientation() }
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
        isLandscape: { false },
        interfaceOrientation: { .portrait }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        deviceType: IssueReporting.unimplemented(placeholder: placeholder()),
        isLandscape: IssueReporting.unimplemented(placeholder: false),
        interfaceOrientation: IssueReporting.unimplemented(placeholder: InterfaceOrientation?.none)
    )
}
