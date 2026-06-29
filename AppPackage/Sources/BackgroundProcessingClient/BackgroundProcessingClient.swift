import BackgroundTasks
import AppModels
import ComposableArchitecture

public enum BackgroundProcessing {
    /// Fixed task identifier, independent of the bundle id. Must stay in sync with the
    /// `BGTaskSchedulerPermittedIdentifiers` entry in Info.plist.
    public static let downloadTaskIdentifier = "app.ehpanda.downloads.processing"
}

/// Wraps `BGTaskScheduler` so the app can ask iOS to relaunch it in a discretionary,
/// multi-minute background window to drain the download queue after the foreground
/// grace period ends. Unlike `BackgroundTaskClient`, this is resolved through
/// `DependencyValues` because both the AppDelegate (registration) and `AppReducer`
/// (scheduling) need it.
@DependencyClient
public struct BackgroundProcessingClient: Sendable {
    /// Registers the launch handler for the download processing task. Must be called
    /// before the app finishes launching.
    public var register: @MainActor @Sendable (@escaping @MainActor @Sendable (BGProcessingTask) -> Void) -> Void
    /// Submits a processing-task request. Best-effort and fire-and-forget: the system may
    /// refuse it (Background App Refresh disabled, identifier not permitted), which the
    /// live implementation logs and tolerates.
    public var schedule: @Sendable () -> Void
    /// Cancels any pending download processing-task request.
    public var cancel: @Sendable () -> Void
}

extension BackgroundProcessingClient {
    public static let live = Self(
        register: { handler in
            _ = BGTaskScheduler.shared.register(
                forTaskWithIdentifier: BackgroundProcessing.downloadTaskIdentifier,
                using: .main
            ) { task in
                guard let processingTask = task as? BGProcessingTask else {
                    task.setTaskCompleted(success: false)
                    return
                }
                handler(processingTask)
            }
        },
        schedule: {
            let request = BGProcessingTaskRequest(
                identifier: BackgroundProcessing.downloadTaskIdentifier
            )
            request.requiresNetworkConnectivity = true
            request.requiresExternalPower = false
            request.earliestBeginDate = nil
            do {
                try BGTaskScheduler.shared.submit(request)
            } catch {
                logger.error("\(error, privacy: .public)")
            }
        },
        cancel: {
            BGTaskScheduler.shared.cancel(
                taskRequestWithIdentifier: BackgroundProcessing.downloadTaskIdentifier
            )
        }
    )
}

// MARK: API
public enum BackgroundProcessingClientKey: DependencyKey {
    public static let liveValue = BackgroundProcessingClient.live
    public static let previewValue = BackgroundProcessingClient.noop
    public static let testValue = BackgroundProcessingClient()
}

extension DependencyValues {
    public var backgroundProcessingClient: BackgroundProcessingClient {
        get { self[BackgroundProcessingClientKey.self] }
        set { self[BackgroundProcessingClientKey.self] = newValue }
    }
}

// MARK: Test
extension BackgroundProcessingClient {
    public static let noop = Self(
        register: { _ in },
        schedule: {},
        cancel: {}
    )
}
