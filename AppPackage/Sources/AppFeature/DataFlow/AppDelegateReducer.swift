import AppModels
import SwiftUI
import Sharing
import BackgroundTasks
import ComposableArchitecture
import AppTools
import AppDelegateClient
import LibraryClient
import DownloadClient
import BackgroundProcessingClient
import CookieClient
import OSLogExt

private let logger = Logger(category: .init(describing: AppDelegateReducer.self))

@Reducer
struct AppDelegateReducer {
    @ObservableState
    struct State: Equatable {}

    enum Action: Equatable {
        case onLaunchFinish
    }

    @Dependency(\.libraryClient) private var libraryClient
    @Dependency(\.cookieClient) private var cookieClient

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .onLaunchFinish:
                // Enforce the browsing-history cap once per launch; in-session upserts never trim.
                @Shared(.galleryHistory) var galleryHistory
                $galleryHistory.withLock { $0.pruneToHistoryCap() }
                return .merge(
                    .run(operation: { _ in libraryClient.initializeWebImage() }),
                    .run(operation: { _ in cookieClient.removeYay() }),
                    .run(operation: { _ in cookieClient.syncExCookies() }),
                    .run(operation: { _ in cookieClient.ignoreOffensive() }),
                    .run(operation: { _ in cookieClient.fulfillAnotherHostField() })
                )
            }
        }
    }
}

// MARK: AppDelegate
public class AppDelegate: UIResponder, UIApplicationDelegate {
    let store = Store(initialState: .init(), reducer: AppReducer.init)

    public override init() {
        super.init()
    }

    public func application(
        _ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask { AppOrientationMask.current }

    public func application(
        _ application: UIApplication, didFinishLaunchingWithOptions
            launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if !AppUtil.isTesting {
            store.send(.appDelegate(.onLaunchFinish))
            // Must register before launch completes so iOS can relaunch us later to
            // drain the download queue in a discretionary background window.
            BackgroundProcessingClient.live.register { task in
                AppDelegate.handleProcessingTask(task)
            }
        }
        return true
    }

    /// Drains the download queue in the granted background window. On expiration the
    /// in-flight work is cancelled and a fresh request is scheduled so iOS can hand the
    /// remaining work back later.
    @MainActor
    static func handleProcessingTask(_ task: BGProcessingTask) {
        @Dependency(\.downloadClient) var downloadClient
        @Dependency(\.backgroundProcessingClient) var backgroundProcessingClient

        let work = Task { @MainActor in
            logger.notice("Background processing started.")
            await downloadClient.runBackgroundProcessing()
            // Reschedule only if we stopped on our own with work still pending; an
            // expiration cancels this task and reschedules from its own handler.
            if !Task.isCancelled, await downloadClient.hasPendingWork() {
                backgroundProcessingClient.schedule()
            }
            task.setTaskCompleted(success: !Task.isCancelled)
            logger.notice("Background processing finished, cancelled: \(Task.isCancelled, privacy: .public).")
        }
        task.expirationHandler = {
            work.cancel()
            backgroundProcessingClient.schedule()
        }
    }

    public func application(
        _ application: UIApplication,
        handleEventsForBackgroundURLSession identifier: String,
        completionHandler: @escaping () -> Void
    ) {
        DownloadBackgroundSessionEvents.setCompletionHandler(
            completionHandler,
            for: identifier
        )
    }
}
