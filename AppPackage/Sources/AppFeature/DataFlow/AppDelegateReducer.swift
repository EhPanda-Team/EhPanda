import AnalyticsClient
import AppModels
import AppTools
import ComposableArchitecture
import CookieClient
import DownloadClient
import LibraryClient
import Sharing
import SwiftUI

@Reducer
struct AppDelegateReducer {
    @ObservableState
    struct State: Equatable {}

    enum Action: Equatable {
        case onLaunchFinish
    }

    @Dependency(\.libraryClient) private var libraryClient
    @Dependency(\.cookieClient) private var cookieClient
    @Dependency(\.analyticsClient) private var analyticsClient

    var body: some Reducer<State, Action> {
        Reduce { _, action in
            switch action {
            case .onLaunchFinish:
                return .merge(
                    // Enforce the browsing-history cap once per launch (in-session upserts never trim).
                    // Runs off the launch path as a background effect — decoding + re-encoding up to
                    // 1,000 entries shouldn't block `didFinishLaunching`; nothing reads history at start.
                    .run { _ in
                        @Shared(.galleryHistory) var galleryHistory
                        $galleryHistory.withLock({ $0.pruneToHistoryCap() })
                    },
                    .run(operation: { _ in libraryClient.initializeWebImage() }),
                    .run(operation: { _ in cookieClient.removeYay() }),
                    .run(operation: { _ in cookieClient.syncExCookies() }),
                    .run(operation: { _ in cookieClient.ignoreOffensive() }),
                    .run(operation: { _ in cookieClient.fulfillAnotherHostField() }),
                    // Initialize the analytics SDK exactly once per process, sequenced through the
                    // launch-finish action alongside the other one-shot client calls — never from a
                    // view lifecycle callback (D-14). This send is already gated behind the app
                    // delegate's `!AppInfo.isTesting` check, so tests never touch the live SDK.
                    .run(operation: { _ in analyticsClient.start() })
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
        _ application: UIApplication, didFinishLaunchingWithOptions
            launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if !AppInfo.isTesting {
            store.send(.appDelegate(.onLaunchFinish))
        }
        return true
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
