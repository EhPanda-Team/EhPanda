//
//  AppLaunchAutomationClient.swift
//  EhPanda
//

import Dependencies

struct AppLaunchAutomationClient: Sendable {
    let current: @Sendable () -> AppLaunchAutomation?
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
    static let testValue = AppLaunchAutomationClient.unimplemented
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

    static func placeholder<Result>() -> Result { fatalError() }

    static let unimplemented: Self = .init(
        current: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
