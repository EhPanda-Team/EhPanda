//
//  BackgroundTaskClient.swift
//  EhPanda
//

import UIKit
import ComposableArchitecture

typealias BackgroundTaskToken = UIBackgroundTaskIdentifier

/// Wraps `UIApplication`'s background-task assertion API so the download coordinator
/// can hold an OS execution assertion while a download is in flight, keeping the
/// in-process orchestration alive through iOS's grace window after backgrounding
/// instead of being suspended within seconds.
///
/// Mirrors `AppDelegateClient`: a plain `Sendable` struct of `@MainActor` closures
/// rather than a `@DependencyClient`, because `begin` both returns a value and takes
/// an escaping handler. It is injected straight into `DownloadCoordinator` (like
/// `pageDownloader`) instead of being resolved through `DependencyValues`.
struct BackgroundTaskClient: Sendable {
    /// Begins a background-task assertion and returns its token. `expirationHandler`
    /// fires when the OS is about to reclaim the assertion; the caller must end it then.
    let begin: @MainActor @Sendable (_ expirationHandler: @escaping @Sendable () -> Void) -> BackgroundTaskToken
    /// Ends a previously begun assertion. A no-op for `.invalid` tokens.
    let end: @MainActor @Sendable (BackgroundTaskToken) -> Void
}

extension BackgroundTaskClient {
    static let live = Self(
        begin: { expirationHandler in
            UIApplication.shared.beginBackgroundTask(
                withName: "app.ehpanda.downloads.assertion",
                expirationHandler: expirationHandler
            )
        },
        end: { token in
            guard token != .invalid else { return }
            UIApplication.shared.endBackgroundTask(token)
        }
    )
}

// MARK: Test
extension BackgroundTaskClient {
    static let noop = Self(
        begin: { _ in .invalid },
        end: { _ in }
    )

    static func placeholder<Result>() -> Result { fatalError() }

    static let unimplemented = Self(
        begin: IssueReporting.unimplemented(placeholder: placeholder()),
        end: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
