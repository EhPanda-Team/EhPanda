import ComposableArchitecture

@DependencyClient
struct AppLaunchAutomationClient: Sendable {
    var current: @Sendable () -> AppLaunchAutomation?
}

extension AppLaunchAutomationClient {
    static let live: Self = .init(
        current: {
            AppLaunchAutomation.current
        }
    )
}

enum AppLaunchAutomationClientKey: DependencyKey {
    static let liveValue = AppLaunchAutomationClient.live
    static let previewValue = AppLaunchAutomationClient.none
    static let testValue = AppLaunchAutomationClient()
}

extension DependencyValues {
    var appLaunchAutomationClient: AppLaunchAutomationClient {
        get { self[AppLaunchAutomationClientKey.self] }
        set { self[AppLaunchAutomationClientKey.self] = newValue }
    }
}

extension AppLaunchAutomationClient {
    static let none: Self = .init(
        current: { nil }
    )
}
