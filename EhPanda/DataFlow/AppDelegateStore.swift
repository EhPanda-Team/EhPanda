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
            hapticClient: .live,
            libraryClient: .live,
            cookiesClient: .live,
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

    case migration(MigrationAction)
}

struct AppDelegateEnvironment {
    let dfClient: DFClient
    let libraryClient: LibraryClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
}

let appDelegateReducer = Reducer<AppState, AppDelegateAction, AppDelegateEnvironment>.combine(
    .init { state, action, environment in
        switch action {
        case .onLaunchFinish:
            state.appLockState.becameInactiveDate = .distantPast
            return .merge(
                environment.libraryClient.initializeLogger().fireAndForget(),
                environment.libraryClient.initializeWebImage().fireAndForget(),
                environment.cookiesClient.removeYay().fireAndForget(),
                environment.cookiesClient.ignoreOffensive().fireAndForget(),
                environment.cookiesClient.fulfillAnotherHostField().fireAndForget(),
                .init(value: .migration(.prepareDatabase))
            )

        case .migration:
            return .none
        }
    },
    migrationReducer.pullback(
        state: \.appDelegateState.migrationState,
        action: /AppDelegateAction.migration,
        environment: {
            .init(
                databaseClient: $0.databaseClient
            )
        }
    )
)
