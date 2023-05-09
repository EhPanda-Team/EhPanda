//
//  AppDelegateStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import SwiftUI
import SwiftyBeaver
import ComposableArchitecture

// MARK: AppDelegate
class AppDelegate: UIResponder, UIApplicationDelegate {
    let store = Store(
        initialState: AppState(),
        reducer: appReducer,
        environment: AppEnvironment(
            dfClient: .live,
            urlClient: .live,
            fileClient: .live,
            imageClient: .live,
            deviceClient: .live,
            loggerClient: .live,
            hapticsClient: .live,
            libraryClient: .live,
            cookieClient: .live,
            databaseClient: .live,
            clipboardClient: .live,
            appDelegateClient: .live,
            userDefaultsClient: .live,
            uiApplicationClient: .live,
            authorizationClient: .live
        )
    )
    lazy var viewStore = ViewStore(store)

    static var orientationMask: UIInterfaceOrientationMask =
        DeviceUtil.isPad ? .all : [.portrait, .portraitUpsideDown]

    func application(
        _ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask { AppDelegate.orientationMask }

    func application(
        _ application: UIApplication, didFinishLaunchingWithOptions
        launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        viewStore.send(.appDelegate(.onLaunchFinish))
        return true
    }
}

struct AppDelegateState: Equatable {
    var migrationState = MigrationState()
}

enum AppDelegateAction {
    case onLaunchFinish
    case removeExpiredImageURLs

    case migration(MigrationAction)
}

struct AppDelegateEnvironment {
    let dfClient: DFClient
    let libraryClient: LibraryClient
    let cookieClient: CookieClient
    let databaseClient: DatabaseClient
}

let appDelegateReducer = Reducer<AppDelegateState, AppDelegateAction, AppDelegateEnvironment>.combine(
    .init { _, action, environment in
        switch action {
        case .onLaunchFinish:
            return .merge(
                environment.libraryClient.initializeLogger().fireAndForget(),
                environment.libraryClient.initializeWebImage().fireAndForget(),
                environment.cookieClient.removeYay().fireAndForget(),
                environment.cookieClient.ignoreOffensive().fireAndForget(),
                environment.cookieClient.fulfillAnotherHostField().fireAndForget(),
                .init(value: .migration(.prepareDatabase))
            )

        case .removeExpiredImageURLs:
            return environment.databaseClient.removeExpiredImageURLs().fireAndForget()

        case .migration:
            return .none
        }
    },
    migrationReducer.pullback(
        state: \.migrationState,
        action: /AppDelegateAction.migration,
        environment: {
            .init(
                databaseClient: $0.databaseClient
            )
        }
    )
)
