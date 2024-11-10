//
//  AppDelegateReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import SwiftUI
import SwiftyBeaver
import ComposableArchitecture

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
class AppDelegate: UIResponder, UIApplicationDelegate {
    let store = Store(initialState: .init()) {
        AppReducer()
    }

    static var orientationMask: UIInterfaceOrientationMask = DeviceUtil.isPad ? .all : [.portrait, .portraitUpsideDown]

    func application(
        _ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask { AppDelegate.orientationMask }

    func application(
        _ application: UIApplication, didFinishLaunchingWithOptions
        launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        if !AppUtil.isTesting {
            store.send(.appDelegate(.onLaunchFinish))
        }
        return true
    }
}
