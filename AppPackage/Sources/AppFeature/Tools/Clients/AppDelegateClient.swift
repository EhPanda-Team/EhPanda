import SwiftUI
import ComposableArchitecture

struct AppDelegateClient: Sendable {
    let setOrientation: @MainActor @Sendable (UIInterfaceOrientationMask) -> Void
    let setOrientationMask: @MainActor @Sendable (UIInterfaceOrientationMask) -> Void
}

extension AppDelegateClient {
    static let live: Self = .init(
        setOrientation: { mask in
            DeviceUtil.keyWindow?.windowScene?.requestGeometryUpdate(.iOS(interfaceOrientations: mask))
        },
        setOrientationMask: { mask in
            AppDelegate.orientationMask = mask
        }
    )

    @MainActor
    func setPortraitOrientation() {
        setOrientation(.portrait)
    }
    @MainActor
    func setAllOrientationMask() {
        setOrientationMask([.all])
    }
    @MainActor
    func setPortraitOrientationMask() {
        setOrientationMask([.portrait, .portraitUpsideDown])
    }
}

// MARK: API
enum AppDelegateClientKey: DependencyKey {
    static let liveValue = AppDelegateClient.live
    static let previewValue = AppDelegateClient.noop
    static let testValue = AppDelegateClient.unimplemented
}

extension DependencyValues {
    var appDelegateClient: AppDelegateClient {
        get { self[AppDelegateClientKey.self] }
        set { self[AppDelegateClientKey.self] = newValue }
    }
}

// MARK: Test
extension AppDelegateClient {
    static let noop: Self = .init(
        setOrientation: { _ in },
        setOrientationMask: { _ in }
    )

    static func placeholder<Result>() -> Result { fatalError() }

    static let unimplemented: Self = .init(
        setOrientation: IssueReporting.unimplemented(placeholder: placeholder()),
        setOrientationMask: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
