//
//  BackgroundProcessingClient.swift
//  EhPanda
//

import BackgroundTasks
import ComposableArchitecture

enum BackgroundProcessing {
    /// Fixed task identifier, independent of the bundle id. Must stay in sync with the
    /// `BGTaskSchedulerPermittedIdentifiers` entry in Info.plist.
    static let downloadTaskIdentifier = "app.ehpanda.downloads.processing"
}

/// Wraps `BGTaskScheduler` so the app can ask iOS to relaunch it in a discretionary,
/// multi-minute background window to drain the download queue after the foreground
/// grace period ends. Unlike `BackgroundTaskClient`, this is resolved through
/// `DependencyValues` because both the AppDelegate (registration) and `AppReducer`
/// (scheduling) need it.
struct BackgroundProcessingClient: Sendable {
    /// Registers the launch handler for the download processing task. Must be called
    /// before the app finishes launching. Returns whether registration succeeded.
    var register: @MainActor @Sendable (_ handler: @escaping @MainActor @Sendable (BGProcessingTask) -> Void) -> Bool
    /// Submits a processing-task request. Returns `false` when the system refuses it
    /// (Background App Refresh disabled, identifier not permitted, etc.) — tolerated.
    var schedule: @Sendable () -> Bool
    /// Cancels any pending download processing-task request.
    var cancel: @Sendable () -> Void
}

extension BackgroundProcessingClient {
    static let live = Self(
        register: { handler in
            BGTaskScheduler.shared.register(
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
                return true
            } catch {
                Logger.error(error)
                return false
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
enum BackgroundProcessingClientKey: DependencyKey {
    static let liveValue = BackgroundProcessingClient.live
    static let previewValue = BackgroundProcessingClient.noop
    static let testValue = BackgroundProcessingClient.unimplemented
}

extension DependencyValues {
    var backgroundProcessingClient: BackgroundProcessingClient {
        get { self[BackgroundProcessingClientKey.self] }
        set { self[BackgroundProcessingClientKey.self] = newValue }
    }
}

// MARK: Test
extension BackgroundProcessingClient {
    static let noop = Self(
        register: { _ in false },
        schedule: { false },
        cancel: {}
    )

    static func placeholder<Result>() -> Result { fatalError() }

    static let unimplemented = Self(
        register: IssueReporting.unimplemented(placeholder: placeholder()),
        schedule: IssueReporting.unimplemented(placeholder: placeholder()),
        cancel: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
