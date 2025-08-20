//
//  AppReducer.swift
//  EhPanda
//

import SwiftUI
import ComposableArchitecture

@Reducer
struct AppReducer {
    @ObservableState
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
                .onChange(of: \.appRouteState.route) { _, newValue in
                    Reduce({ _, _ in newValue == nil ? .send(.appRoute(.clearSubStates)) : .none })
                }
                .onChange(of: \.settingState.setting) { _, _ in
                    Reduce({ _, _ in .send(.setting(.syncSetting)) })
                }

            Reduce { state, action in
                switch action {
                case .binding:
                    return .none

                case .onScenePhaseChange(let scenePhase):
                    guard state.settingState.hasLoadedInitialSetting else { return .none }

                    switch scenePhase {
                    case .active:
                        let threshold = state.settingState.setting.autoLockPolicy.rawValue
                        let blurRadius = state.settingState.setting.backgroundBlurRadius
                        return .send(.appLock(.onBecomeActive(threshold, blurRadius)))

                    case .inactive:
                        let blurRadius = state.settingState.setting.backgroundBlurRadius
                        return .send(.appLock(.onBecomeInactive(blurRadius)))

                    default:
                        return .none
                    }

                case .appDelegate(.migration(.onDatabasePreparationSuccess)):
                    return .merge(
                        .send(.appDelegate(.removeExpiredImageURLs)),
                        .send(.setting(.loadUserSettings))
                    )

                case .appDelegate:
                    return .none

                case .appRoute(.clearSubStates):
                    var effects = [Effect<Action>]()
                    if deviceClient.isPad() {
                        state.settingState.route = nil
                        effects.append(.send(.setting(.clearSubStates)))
                    }
                    return effects.isEmpty ? .none : .merge(effects)

                case .appRoute:
                    return .none

                case .appLock(.unlockApp):
                    var effects: [Effect<Action>] = [
                        .send(.setting(.fetchGreeting))
                    ]
                    if state.settingState.setting.detectsLinksFromClipboard {
                        effects.append(.send(.appRoute(.detectClipboardURL)))
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
                                effects.append(.send(.home(.setNavigation(nil))))
                            } else {
                                effects.append(.send(.home(.fetchAllGalleries)))
                            }
                        case .favorites:
                            if state.favoritesState.route != nil {
                                effects.append(.send(.favorites(.setNavigation(nil))))
                                effects.append(hapticEffect)
                            } else if cookieClient.didLogin {
                                effects.append(.send(.favorites(.fetchGalleries())))
                                effects.append(hapticEffect)
                            }
                        case .search:
                            if state.searchRootState.route != nil {
                                effects.append(.send(.searchRoot(.setNavigation(nil))))
                            } else {
                                effects.append(.send(.searchRoot(.fetchDatabaseInfos)))
                            }
                        case .setting:
                            if state.settingState.route != nil {
                                effects.append(.send(.setting(.setNavigation(nil))))
                                effects.append(hapticEffect)
                            }
                        }
                        if [.home, .search].contains(type) {
                            effects.append(hapticEffect)
                        }
                    }
                    if type == .setting && deviceClient.isPad() {
                        effects.append(.send(.appRoute(.setNavigation(.setting()))))
                    }
                    return effects.isEmpty ? .none : .merge(effects)

                case .tabBar:
                    return .none

                case .home(.watched(.onNotLoginViewButtonTapped)), .favorites(.onNotLoginViewButtonTapped):
                    var effects: [Effect<Action>] = [
                        .run(operation: { _ in hapticsClient.generateFeedback(.soft) }),
                        .send(.tabBar(.setTabBarItemType(.setting)))
                    ]
                    effects.append(.send(.setting(.setNavigation(.account))))
                    if !cookieClient.didLogin {
                        effects.append(
                            .run { send in
                                let delay = UInt64(deviceClient.isPad() ? 1200 : 200)
                                try await Task.sleep(for: .milliseconds(delay))
                                await send(.setting(.account(.setNavigation(.login))))
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
                        effects.append(.send(.appLock(.onBecomeActive(threshold, blurRadius))))
                    }
                    if state.settingState.setting.detectsLinksFromClipboard {
                        effects.append(.send(.appRoute(.detectClipboardURL)))
                    }
                    return effects.isEmpty ? .none : .merge(effects)

                case .setting(.fetchGreetingDone(let result)):
                    return .send(.appRoute(.fetchGreetingDone(result)))

                case .setting:
                    return .none
                }
            }

            Scope(state: \.appRouteState, action: \.appRoute, child: AppRouteReducer.init)
            Scope(state: \.appLockState, action: \.appLock, child: AppLockReducer.init)
            Scope(state: \.appDelegateState, action: \.appDelegate, child: AppDelegateReducer.init)
            Scope(state: \.tabBarState, action: \.tabBar, child: TabBarReducer.init)
            Scope(state: \.homeState, action: \.home, child: HomeReducer.init)
            Scope(state: \.favoritesState, action: \.favorites, child: FavoritesReducer.init)
            Scope(state: \.searchRootState, action: \.searchRoot, child: SearchRootReducer.init)
            Scope(state: \.settingState, action: \.setting, child: SettingReducer.init)
        }
    }
}
