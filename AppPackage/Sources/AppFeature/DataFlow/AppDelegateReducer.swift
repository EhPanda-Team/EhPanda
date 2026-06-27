import SwiftUI
import BackgroundTasks
import SwiftyBeaver
import ComposableArchitecture
import Utilities
import LibraryClient
import DatabaseClient

@Reducer
struct AppDelegateReducer {
    @ObservableState
    struct State: Equatable {
        var migrationState = MigrationReducer.State()
    }

    enum Action: Equatable {
        case onLaunchFinish
        case removeExpiredImageURLs

        case migration(MigrationReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.libraryClient) private var libraryClient
    @Dependency(\.cookieClient) private var cookieClient

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .onLaunchFinish:
                return .merge(
                    .run(operation: { _ in libraryClient.initializeLogger() }),
                    .run(operation: { _ in libraryClient.initializeWebImage() }),
                    .run(operation: { _ in cookieClient.removeYay() }),
                    .run(operation: { _ in cookieClient.syncExCookies() }),
                    .run(operation: { _ in cookieClient.ignoreOffensive() }),
                    .run(operation: { _ in cookieClient.fulfillAnotherHostField() }),
                    .send(.migration(.prepareDatabase))
                )

            case .removeExpiredImageURLs:
                return .run(operation: { _ in await databaseClient.removeExpiredImageURLs() })

            case .migration:
                return .none
            }
        }

        Scope(state: \.migrationState, action: \.migration, child: MigrationReducer.init)
    }
}

// MARK: AppDelegate
public class AppDelegate: UIResponder, UIApplicationDelegate {
    let store = Store(initialState: .init(), reducer: AppReducer.init)

    public override init() {
        super.init()
    }

    static var orientationMask: UIInterfaceOrientationMask = DeviceUtil.isPad ? .all : [.portrait, .portraitUpsideDown]

    public func application(
        _ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask { AppDelegate.orientationMask }

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
            await downloadClient.runBackgroundProcessing()
            // Reschedule only if we stopped on our own with work still pending; an
            // expiration cancels this task and reschedules from its own handler.
            if !Task.isCancelled, await downloadClient.hasPendingWork() {
                backgroundProcessingClient.schedule()
            }
            task.setTaskCompleted(success: !Task.isCancelled)
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
