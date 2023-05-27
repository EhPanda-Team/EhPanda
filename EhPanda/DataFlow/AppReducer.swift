//
//  AppReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import SwiftUI
import ComposableArchitecture

struct AppReducer: ReducerProtocol {
    struct State: Equatable {
        var appDelegateState = AppDelegateReducer.State()
        var appRouteState = AppRouteReducer.State()
        var appLockState = AppLockReducer.State()
        var tabBarState = TabBarReducer.State()
        var homeState = HomeReducer.State()
        var favoritesState = FavoritesReducer.State()
        var searchRootState = SearchRootReducer.State()
        var settingState = SettingReducer.State()
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onScenePhaseChange(ScenePhase)

        case appDelegate(AppDelegateReducer.Action)
        case appRoute(AppRouteReducer.Action)
        case appLock(AppLockReducer.Action)

        case tabBar(TabBarReducer.Action)

        case home(HomeReducer.Action)
        case favorites(FavoritesReducer.Action)
        case searchRoot(SearchRootReducer.Action)
        case setting(SettingReducer.Action)
    }

    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.cookieClient) private var cookieClient
    @Dependency(\.deviceClient) private var deviceClient

    var body: some ReducerProtocol<State, Action> {
        LoggingReducer {
            BindingReducer()

            Reduce { state, action in
                switch action {
                case .binding(\.appRouteState.$route):
                    return state.appRouteState.route == nil ? .init(value: .appRoute(.clearSubStates)) : .none

                case .binding(\.settingState.$setting):
                    return .init(value: .setting(.syncSetting))

                case .binding:
                    return .none

                case .onScenePhaseChange(let scenePhase):
                    switch scenePhase {
                    case .active:
                        let threshold = state.settingState.setting.autoLockPolicy.rawValue
                        let blurRadius = state.settingState.setting.backgroundBlurRadius
                        return .init(value: .appLock(.onBecomeActive(threshold, blurRadius)))
                    case .inactive:
                        let blurRadius = state.settingState.setting.backgroundBlurRadius
                        return .init(value: .appLock(.onBecomeInactive(blurRadius)))
                    default:
                        break
                    }
                    return .none

                case .appDelegate(.migration(.onDatabasePreparationSuccess)):
                    return .merge(
                        .init(value: .appDelegate(.removeExpiredImageURLs)),
                        .init(value: .setting(.loadUserSettings))
                    )

                case .appDelegate:
                    return .none

                case .appRoute(.clearSubStates):
                    var effects = [EffectTask<Action>]()
                    if deviceClient.isPad() {
                        state.settingState.route = nil
                        effects.append(.init(value: .setting(.clearSubStates)))
                    }
                    return effects.isEmpty ? .none : .merge(effects)

                case .appRoute:
                    return .none

                case .appLock(.unlockApp):
                    var effects: [EffectTask<Action>] = [
                        .init(value: .setting(.fetchGreeting))
                    ]
                    if state.settingState.setting.detectsLinksFromClipboard {
                        effects.append(.init(value: .appRoute(.detectClipboardURL)))
                    }
                    return .merge(effects)

                case .appLock:
                    return .none

                case .tabBar(.setTabBarItemType(let type)):
                    var effects = [EffectTask<Action>]()
                    let hapticEffect: EffectTask<Action> = .fireAndForget({ hapticsClient.generateFeedback(.soft) })
                    if type == state.tabBarState.tabBarItemType {
                        switch type {
                        case .home:
                            if state.homeState.route != nil {
                                effects.append(.init(value: .home(.setNavigation(nil))))
                            } else {
                                effects.append(.init(value: .home(.fetchAllGalleries)))
                            }
                        case .favorites:
                            if state.favoritesState.route != nil {
                                effects.append(.init(value: .favorites(.setNavigation(nil))))
                                effects.append(hapticEffect)
                            } else if cookieClient.didLogin {
                                effects.append(.init(value: .favorites(.fetchGalleries())))
                                effects.append(hapticEffect)
                            }
                        case .search:
                            if state.searchRootState.route != nil {
                                effects.append(.init(value: .searchRoot(.setNavigation(nil))))
                            } else {
                                effects.append(.init(value: .searchRoot(.fetchDatabaseInfos)))
                            }
                        case .setting:
                            if state.settingState.route != nil {
                                effects.append(.init(value: .setting(.setNavigation(nil))))
                                effects.append(hapticEffect)
                            }
                        }
                        if [.home, .search].contains(type) {
                            effects.append(hapticEffect)
                        }
                    }
                    if type == .setting && deviceClient.isPad() {
                        effects.append(.init(value: .appRoute(.setNavigation(.setting))))
                    }
                    return effects.isEmpty ? .none : .merge(effects)

                case .tabBar:
                    return .none

                case .home(.watched(.onNotLoginViewButtonTapped)), .favorites(.onNotLoginViewButtonTapped):
                    var effects: [EffectTask<Action>] = [
                        .fireAndForget({ hapticsClient.generateFeedback(.soft) }),
                        .init(value: .tabBar(.setTabBarItemType(.setting)))
                    ]
                    effects.append(.init(value: .setting(.setNavigation(.account))))
                    if !cookieClient.didLogin {
                        effects.append(
                            .init(value: .setting(.account(.setNavigation(.login))))
                            .delay(
                                for: .milliseconds(deviceClient.isPad() ? 1200 : 200),
                                scheduler: DispatchQueue.main
                            )
                            .eraseToEffect()
                        )
                    }
                    return .merge(effects)

                case .home:
                    return .none

                case .favorites:
                    return .none

                case .searchRoot:
                    return .none

                case .setting(.loadUserSettingsDone):
                    var effects = [EffectTask<Action>]()
                    let threshold = state.settingState.setting.autoLockPolicy.rawValue
                    let blurRadius = state.settingState.setting.backgroundBlurRadius
                    if threshold >= 0 {
                        state.appLockState.becameInactiveDate = .distantPast
                        effects.append(.init(value: .appLock(.onBecomeActive(threshold, blurRadius))))
                    }
                    if state.settingState.setting.detectsLinksFromClipboard {
                        effects.append(.init(value: .appRoute(.detectClipboardURL)))
                    }
                    return effects.isEmpty ? .none : .merge(effects)

                case .setting(.fetchGreetingDone(let result)):
                    return .init(value: .appRoute(.fetchGreetingDone(result)))

                case .setting:
                    return .none
                }
            }

            Scope(state: \.appRouteState, action: /Action.appRoute, child: AppRouteReducer.init)
            Scope(state: \.appLockState, action: /Action.appLock, child: AppLockReducer.init)
            Scope(state: \.appDelegateState, action: /Action.appDelegate, child: AppDelegateReducer.init)
            Scope(state: \.tabBarState, action: /Action.tabBar, child: TabBarReducer.init)
            Scope(state: \.homeState, action: /Action.home, child: HomeReducer.init)
            Scope(state: \.favoritesState, action: /Action.favorites, child: FavoritesReducer.init)
            Scope(state: \.searchRootState, action: /Action.searchRoot, child: SearchRootReducer.init)
            Scope(state: \.settingState, action: /Action.setting, child: SettingReducer.init)
        }
    }
}
