//
//  AppDelegate.swift
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
            fileClient: .live,
            loggerClient: .live,
            hapticClient: .live,
            libraryClient: .live,
            cookiesClient: .live,
            databaseClient: .live,
            userDefaultsClient: .live,
            uiApplicationClient: .live,
            authorizationClient: .live
        )
    )
    lazy var viewStore = ViewStore(store.stateless)

    static var orientationLock: UIInterfaceOrientationMask =
        DeviceUtil.isPad ? .all : [.portrait, .portraitUpsideDown]

    func application(
        _ application: UIApplication, supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask { AppDelegate.orientationLock }

    func application(
        _ application: UIApplication, didFinishLaunchingWithOptions
        launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        viewStore.send(.appDelegate(.didFinishLaunching))
        viewStore.send(.setting(.didFinishLaunching))
        return true
    }
}

enum AppDelegateAction {
    case didFinishLaunching
}

struct AppDelegateEnvironment {
    let dfClient: DFClient
    let libraryClient: LibraryClient
    let cookiesClient: CookiesClient
}

let appDelegateReducer = Reducer<Bool, AppDelegateAction, AppDelegateEnvironment> { state, action, environment in
    switch action {
    case .didFinishLaunching:
        return .merge(
            environment.libraryClient.initializeLogger().fireAndForget(),
            environment.libraryClient.initializeWebImage().fireAndForget(),
            environment.dfClient.setActive(state).fireAndForget(),
            environment.cookiesClient.removeYay().fireAndForget(),
            environment.cookiesClient.ignoreOffensive().fireAndForget(),
            environment.cookiesClient.fulfillAnotherHostField().fireAndForget()
        )
    }
}
