import ComposableArchitecture

@DependencyClient
public struct AppLaunchAutomationClient: Sendable {
    public var current: @Sendable () -> AppLaunchAutomation?
}

extension AppLaunchAutomationClient {
    public static let live: Self = .init(
        current: {
            AppLaunchAutomation.current
        }
    )
}

public enum AppLaunchAutomationClientKey: DependencyKey {
    public static let liveValue = AppLaunchAutomationClient.live
    public static let previewValue = AppLaunchAutomationClient.none
    public static let testValue = AppLaunchAutomationClient()
}

extension DependencyValues {
    public var appLaunchAutomationClient: AppLaunchAutomationClient {
        get { self[AppLaunchAutomationClientKey.self] }
        set { self[AppLaunchAutomationClientKey.self] = newValue }
    }
}

extension AppLaunchAutomationClient {
    public static let none: Self = .init(
        current: { nil }
    )
}
