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
        initialState: AltAppState(),
        reducer: appReducer,
        environment: AppEnvironment(
            dfClient: .live,
            libraryClient: .live,
            cookiesClient: .live
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
        viewStore.send(.sharedData(.didFinishLaunching))
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
            environment.libraryClient.initializeKingfisher().fireAndForget(),
            environment.libraryClient.initializeSwiftyBeaver().fireAndForget(),
            environment.dfClient.setActive(state).fireAndForget(),
            environment.cookiesClient.removeYay().fireAndForget(),
            environment.cookiesClient.ignoreOffensive().fireAndForget()
        )
    }
}
