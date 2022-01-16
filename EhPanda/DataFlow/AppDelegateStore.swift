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
            deviceClient: .live,
            loggerClient: .live,
            hapticClient: .live,
            libraryClient: .live,
            cookiesClient: .live,
            databaseClient: .live,
            appDelegateClient: .live,
            userDefaultsClient: .live,
            uiApplicationClient: .live,
            authorizationClient: .live
        )
    )
    lazy var viewStore = ViewStore(store.stateless)

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
        viewStore.send(.setting(.loadUserSettings))
        return true
    }
}

enum AppDelegateAction {
    case onLaunchFinish
}

struct AppDelegateEnvironment {
    let dfClient: DFClient
    let libraryClient: LibraryClient
    let cookiesClient: CookiesClient
}

let appDelegateReducer = Reducer<AppState, AppDelegateAction, AppDelegateEnvironment> { state, action, environment in
    switch action {
    case .onLaunchFinish:
        let bypassesSNIFiltering = state.settingState.setting.bypassesSNIFiltering
        state.appLockState.becomeInactiveDate = .distantPast
        return .merge(
            environment.libraryClient.initializeLogger().fireAndForget(),
            environment.libraryClient.initializeWebImage().fireAndForget(),
            environment.dfClient.setActive(bypassesSNIFiltering).fireAndForget(),
            environment.cookiesClient.removeYay().fireAndForget(),
            environment.cookiesClient.ignoreOffensive().fireAndForget(),
            environment.cookiesClient.fulfillAnotherHostField().fireAndForget()
        )
    }
}
