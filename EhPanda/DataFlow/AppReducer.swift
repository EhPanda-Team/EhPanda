//
//  AppReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import SwiftUI
import ComposableArchitecture

struct AppReducer: Reducer {
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

    var body: some Reducer<State, Action> {
        LoggingReducer {
            BindingReducer()

            Reduce { state, action in
                switch action {
                case .binding(\.appRouteState.$route):
                    return state.appRouteState.route == nil ? Effect.send(.appRoute(.clearSubStates)) : .none

                case .binding(\.settingState.$setting):
                    return Effect.send(.setting(.syncSetting))

                case .binding:
                    return .none

                case .onScenePhaseChange(let scenePhase):
                    guard state.settingState.hasLoadedInitialSetting else { return .none }

                    switch scenePhase {
                    case .active:
                        let threshold = state.settingState.setting.autoLockPolicy.rawValue
                        let blurRadius = state.settingState.setting.backgroundBlurRadius
                        return Effect.send(.appLock(.onBecomeActive(threshold, blurRadius)))

                    case .inactive:
                        let blurRadius = state.settingState.setting.backgroundBlurRadius
                        return Effect.send(.appLock(.onBecomeInactive(blurRadius)))

                    default:
                        return .none
                    }

                case .appDelegate(.migration(.onDatabasePreparationSuccess)):
                    return .merge(
                        Effect.send(.appDelegate(.removeExpiredImageURLs)),
                        Effect.send(.setting(.loadUserSettings))
                    )

                case .appDelegate:
                    return .none

                case .appRoute(.clearSubStates):
                    var effects = [Effect<Action>]()
                    if deviceClient.isPad() {
                        state.settingState.route = nil
                        effects.append(Effect.send(.setting(.clearSubStates)))
                    }
                    return effects.isEmpty ? .none : .merge(effects)

                case .appRoute:
                    return .none

                case .appLock(.unlockApp):
                    var effects: [Effect<Action>] = [
                        Effect.send(.setting(.fetchGreeting))
                    ]
                    if state.settingState.setting.detectsLinksFromClipboard {
                        effects.append(Effect.send(.appRoute(.detectClipboardURL)))
                    }
                    return .merge(effects)

                case .appLock:
                    return .none

                case .tabBar(.setTabBarItemType(let type)):
                    var effects = [Effect<Action>]()
                    let hapticEffect: Effect<Action> = .run(operation: { _ in hapticsClient.generateFeedback(.soft) })
                    if type == state.tabBarState.tabBarItemType {
                        switch type {
                        case .home:
                            if state.homeState.route != nil {
                                effects.append(Effect.send(.home(.setNavigation(nil))))
                            } else {
                                effects.append(Effect.send(.home(.fetchAllGalleries)))
                            }
                        case .favorites:
                            if state.favoritesState.route != nil {
                                effects.append(Effect.send(.favorites(.setNavigation(nil))))
                                effects.append(hapticEffect)
                            } else if cookieClient.didLogin {
                                effects.append(Effect.send(.favorites(.fetchGalleries())))
                                effects.append(hapticEffect)
                            }
                        case .search:
                            if state.searchRootState.route != nil {
                                effects.append(Effect.send(.searchRoot(.setNavigation(nil))))
                            } else {
                                effects.append(Effect.send(.searchRoot(.fetchDatabaseInfos)))
                            }
                        case .setting:
                            if state.settingState.route != nil {
                                effects.append(Effect.send(.setting(.setNavigation(nil))))
                                effects.append(hapticEffect)
                            }
                        }
                        if [.home, .search].contains(type) {
                            effects.append(hapticEffect)
                        }
                    }
                    if type == .setting && deviceClient.isPad() {
                        effects.append(Effect.send(.appRoute(.setNavigation(.setting))))
                    }
                    return effects.isEmpty ? .none : .merge(effects)

                case .tabBar:
                    return .none

                case .home(.watched(.onNotLoginViewButtonTapped)), .favorites(.onNotLoginViewButtonTapped):
                    var effects: [Effect<Action>] = [
                        .run(operation: { _ in hapticsClient.generateFeedback(.soft) }),
                        Effect.send(.tabBar(.setTabBarItemType(.setting)))
                    ]
                    effects.append(Effect.send(.setting(.setNavigation(.account))))
                    if !cookieClient.didLogin {
                        effects.append(
                            Effect.publisher {
                                Effect.send(.setting(.account(.setNavigation(.login))))
                                    .delay(
                                        for: .milliseconds(deviceClient.isPad() ? 1200 : 200),
                                        scheduler: DispatchQueue.main
                                    )
                            }
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
                    var effects = [Effect<Action>]()
                    let threshold = state.settingState.setting.autoLockPolicy.rawValue
                    let blurRadius = state.settingState.setting.backgroundBlurRadius
                    if threshold >= 0 {
                        state.appLockState.becameInactiveDate = .distantPast
                        effects.append(Effect.send(.appLock(.onBecomeActive(threshold, blurRadius))))
                    }
                    if state.settingState.setting.detectsLinksFromClipboard {
                        effects.append(Effect.send(.appRoute(.detectClipboardURL)))
                    }
                    return effects.isEmpty ? .none : .merge(effects)

                case .setting(.fetchGreetingDone(let result)):
                    return Effect.send(.appRoute(.fetchGreetingDone(result)))

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
