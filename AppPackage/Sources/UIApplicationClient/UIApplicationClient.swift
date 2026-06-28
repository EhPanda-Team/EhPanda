import SwiftUI
import Combine
import ComposableArchitecture
import Utilities

public struct UIApplicationClient: Sendable {
    public let openURL: @MainActor @Sendable (URL) -> Void
    public let hideKeyboard: @Sendable () async -> Void
    public let alternateIconName: @MainActor @Sendable () -> String?
    public let setAlternateIconName: @MainActor @Sendable (String?) async -> Bool
    public let setUserInterfaceStyle: @MainActor @Sendable (UIUserInterfaceStyle) -> Void
}

extension UIApplicationClient {
    public static let live: Self = .init(
        openURL: { url in
            UIApplication.shared.open(url, options: [:])
        },
        hideKeyboard: {
            await MainActor.run {
                UIApplication.shared.endEditing()
            }
        },
        alternateIconName: {
            UIApplication.shared.alternateIconName
        },
        setAlternateIconName: { iconName in
            await withCheckedContinuation { continuation in
                UIApplication.shared.setAlternateIconName(iconName) { error in
                    if let error = error {
                        continuation.resume(returning: false)
                    } else {
                        continuation.resume(returning: true)
                    }
                }
            }
        },
        setUserInterfaceStyle: { userInterfaceStyle in
            (DeviceUtil.keyWindow ?? DeviceUtil.anyWindow)?.overrideUserInterfaceStyle = userInterfaceStyle
        }
    )
    @MainActor
    public func openSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            return openURL(url)
        }
    }
    @MainActor
    public func openFileApp() {
        let dirPath = FileUtil.logsDirectoryURL.path
        if let dirURL = URL(string: "shareddocuments://" + dirPath) {
            return openURL(dirURL)
        }
    }
}

// MARK: API
public enum UIApplicationClientKey: DependencyKey {
    public static let liveValue = UIApplicationClient.live
    public static let previewValue = UIApplicationClient.noop
    public static let testValue = UIApplicationClient.unimplemented
}

extension DependencyValues {
    public var uiApplicationClient: UIApplicationClient {
        get { self[UIApplicationClientKey.self] }
        set { self[UIApplicationClientKey.self] = newValue }
    }
}

// MARK: Test
extension UIApplicationClient {
    public static let noop: Self = .init(
        openURL: { _ in},
        hideKeyboard: {},
        alternateIconName: { nil },
        setAlternateIconName: { _ in false },
        setUserInterfaceStyle: { _ in }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        openURL: IssueReporting.unimplemented(placeholder: placeholder()),
        hideKeyboard: IssueReporting.unimplemented(placeholder: placeholder()),
        alternateIconName: IssueReporting.unimplemented(placeholder: placeholder()),
        setAlternateIconName: IssueReporting.unimplemented(placeholder: placeholder()),
        setUserInterfaceStyle: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
