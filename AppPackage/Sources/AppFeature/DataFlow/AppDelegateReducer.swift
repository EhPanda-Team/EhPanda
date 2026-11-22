import AppModels
import AppTools
public import ComposableArchitecture
import CrashReporting
import DownloadClient
import Foundation
import LibraryClient
import OSLogExt
import Sharing
import SwiftUI
public import UIKit

private let logger = Logger(category: .init(describing: AppDelegateReducer.self))

@Reducer
struct AppDelegateReducer {
    @ObservableState
    struct State: Equatable {}

    enum Action: Equatable {
        case onLaunchFinish
    }

    @Dependency(\.libraryClient) private var libraryClient

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
                    // The analytics SDK no longer starts here; it waits behind `AppReducer`'s first-launch gate.
                    .run(operation: { _ in libraryClient.initializeWebImage() })
                )
            }
        }
    }
}

// MARK: AppDelegate
public class AppDelegate: UIResponder, UIApplicationDelegate {
    let store: StoreOf<AppReducer>

    public override init() {
        #if DEBUG
        let configuration = UITestAutomation.prepare(environment: ProcessInfo.processInfo.environment)
        #endif
        store = Store(initialState: .init(), reducer: AppReducer.init) { dependencies in
            #if DEBUG
            if let configuration, configuration.shouldUseVisualTestHost {
                UITestAutomation.configureVisualTestHost(
                    &dependencies, firstLaunch: configuration.firstLaunchPreset
                )
            }
            #endif
        }
        super.init()
    }

    public func application(
        _ application: UIApplication, didFinishLaunchingWithOptions
            launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Crash reporting starts first, so that a crash anywhere later in launch is still caught. It neither
        // waits for nor depends on the analytics choice, because crash reports are not analytics data. The
        // start rule itself refuses Debug builds, test hosts and builds without a DSN.
        CrashReporter.start()
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
