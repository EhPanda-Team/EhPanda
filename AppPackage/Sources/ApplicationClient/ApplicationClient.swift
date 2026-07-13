import SwiftUI
import ComposableArchitecture
import AppTools

public struct ApplicationClient: Sendable {
    public let openURL: @MainActor @Sendable (URL) -> Void
    public let hideKeyboard: @Sendable () async -> Void
    public let alternateIconName: @MainActor @Sendable () -> String?
    public let setAlternateIconName: @MainActor @Sendable (String?) async -> Bool
    public let setUserInterfaceStyle: @MainActor @Sendable (UIUserInterfaceStyle) -> Void
}

extension ApplicationClient {
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
            interfaceStyleWindow()?.overrideUserInterfaceStyle = userInterfaceStyle
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
public enum ApplicationClientKey: DependencyKey {
    public static let liveValue = ApplicationClient.live
    public static let previewValue = ApplicationClient.noop
    public static let testValue = ApplicationClient.unimplemented
}

extension DependencyValues {
    public var applicationClient: ApplicationClient {
        get { self[ApplicationClientKey.self] }
        set { self[ApplicationClientKey.self] = newValue }
    }
}

// MARK: Test
extension ApplicationClient {
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

@MainActor
private func interfaceStyleWindow() -> UIWindow? {
    let keyWindow = UIApplication.shared.connectedScenes
        .filter { $0.activationState == .foregroundActive }
        .compactMap { $0 as? UIWindowScene }
        .last?
        .windows
        .filter(\.isKeyWindow)
        .last
    let anyWindow = UIApplication.shared.connectedScenes
        .compactMap { $0 as? UIWindowScene }
        .last?
        .windows
        .last
    return keyWindow ?? anyWindow
}
