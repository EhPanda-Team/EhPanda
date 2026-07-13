import UIKit
import ComposableArchitecture

public typealias BackgroundTaskToken = UIBackgroundTaskIdentifier

/// Wraps `UIApplication`'s background-task assertion API so the download coordinator
/// can hold an OS execution assertion while a download is in flight, keeping the
/// in-process orchestration alive through iOS's grace window after backgrounding
/// instead of being suspended within seconds.
///
/// This is a plain `Sendable` struct of `@MainActor` closures rather than a
/// `@DependencyClient`. It is injected straight into `DownloadCoordinator`
/// (like `pageDownloader`) rather than being resolved through `DependencyValues`, so it
/// has no place for the macro's auto-generated unimplemented `testValue` to live.
public struct BackgroundTaskClient: Sendable {
    /// Begins a background-task assertion and returns its token. `expirationHandler`
    /// fires when the OS is about to reclaim the assertion; the caller must end it then.
    public let begin: @MainActor @Sendable (_ expirationHandler: @escaping @Sendable () -> Void) -> BackgroundTaskToken
    /// Ends a previously begun assertion. A no-op for `.invalid` tokens.
    public let end: @MainActor @Sendable (BackgroundTaskToken) -> Void

    public init(
        begin: @escaping @MainActor @Sendable (
            _ expirationHandler: @escaping @Sendable () -> Void
        ) -> BackgroundTaskToken,
        end: @escaping @MainActor @Sendable (BackgroundTaskToken) -> Void
    ) {
        self.begin = begin
        self.end = end
    }
}

extension BackgroundTaskClient {
    public static let live = Self(
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
    public static let noop = Self(
        begin: { _ in .invalid },
        end: { _ in }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented = Self(
        begin: IssueReporting.unimplemented(placeholder: placeholder()),
        end: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
