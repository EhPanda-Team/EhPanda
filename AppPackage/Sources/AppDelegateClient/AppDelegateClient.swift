import SwiftUI
import ComposableArchitecture
import AppTools

public struct AppDelegateClient: Sendable {
    public let setOrientation: @MainActor @Sendable (UIInterfaceOrientationMask) -> Void
    public let setOrientationMask: @MainActor @Sendable (UIInterfaceOrientationMask) -> Void
}

extension AppDelegateClient {
    public static let live: Self = .init(
        setOrientation: { mask in
            DeviceUtil.keyWindow?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        },
        setOrientationMask: { mask in
            AppOrientationMask.current = mask
        }
    )

    @MainActor
    public func setPortraitOrientation() {
        setOrientation(.portrait)
    }
    @MainActor
    public func setAllOrientationMask() {
        setOrientationMask([.all])
    }
    @MainActor
    public func setPortraitOrientationMask() {
        setOrientationMask([.portrait, .portraitUpsideDown])
    }
}

// MARK: API
public enum AppDelegateClientKey: DependencyKey {
    public static let liveValue = AppDelegateClient.live
    public static let previewValue = AppDelegateClient.noop
    public static let testValue = AppDelegateClient.unimplemented
}

extension DependencyValues {
    public var appDelegateClient: AppDelegateClient {
        get { self[AppDelegateClientKey.self] }
        set { self[AppDelegateClientKey.self] = newValue }
    }
}

// MARK: Test
extension AppDelegateClient {
    public static let noop: Self = .init(
        setOrientation: { _ in },
        setOrientationMask: { _ in }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        setOrientation: IssueReporting.unimplemented(placeholder: placeholder()),
        setOrientationMask: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
