//
//  TabBarView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/29.
//

import SwiftUI
import SFSafeSymbols
import ComposableArchitecture

struct TabBarView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var store: StoreOf<AppReducer>

    init(store: StoreOf<AppReducer>) {
        self.store = store
    }

    var body: some View {
        ZStack {
            TabView(
                selection: .init(
                    get: { store.tabBarState.tabBarItemType },
                    set: { store.send(.tabBar(.setTabBarItemType($0))) }
                )
            ) {
                ForEach(TabBarItemType.allCases) { type in
                    Group {
                        switch type {
                        case .home:
                            HomeView(
                                store: store.scope(state: \.homeState, action: \.home),
                                user: store.settingState.user,
                                setting: $store.settingState.setting,
                                blurRadius: store.appLockState.blurRadius,
                                tagTranslator: store.settingState.tagTranslator
                            )
                        case .favorites:
                            FavoritesView(
                                store: store.scope(state: \.favoritesState, action: \.favorites),
                                user: store.settingState.user,
                                setting: $store.settingState.setting,
                                blurRadius: store.appLockState.blurRadius,
                                tagTranslator: store.settingState.tagTranslator
                            )
                        case .search:
                            SearchRootView(
                                store: store.scope(state: \.searchRootState, action: \.searchRoot),
                                user: store.settingState.user,
                                setting: $store.settingState.setting,
                                blurRadius: store.appLockState.blurRadius,
                                tagTranslator: store.settingState.tagTranslator
                            )
                        case .setting:
                            SettingView(
                                store: store.scope(state: \.settingState, action: \.setting),
                                blurRadius: store.appLockState.blurRadius
                            )
                        }
                    }
                    .tabItem(type.label).tag(type)
                }
                .accentColor(store.settingState.setting.accentColor)
            }
            .autoBlur(radius: store.appLockState.blurRadius)
            Button {
                store.send(.appLock(.authorize))
            } label: {
                Image(systemSymbol: .lockFill)
            }
            .font(.system(size: 80)).opacity(store.appLockState.isAppLocked ? 1 : 0)
        }
        .sheet(unwrapping: $store.appRouteState.route, case: /AppRouteReducer.Route.newDawn) { route in
            NewDawnView(greeting: route.wrappedValue)
                .autoBlur(radius: store.appLockState.blurRadius)
        }
        .sheet(unwrapping: $store.appRouteState.route, case: /AppRouteReducer.Route.setting) { _ in
            SettingView(
                store: store.scope(state: \.settingState, action: \.setting),
                blurRadius: store.appLockState.blurRadius
            )
            .accentColor(store.settingState.setting.accentColor)
            .autoBlur(radius: store.appLockState.blurRadius)
        }
        .sheet(unwrapping: $store.appRouteState.route, case: /AppRouteReducer.Route.detail) { route in
            NavigationView {
                DetailView(
                    store: store.scope(
                        state: \.appRouteState.detailState.wrappedValue!,
                        action: \.appRoute.detail
                    ),
                    gid: route.wrappedValue, user: store.settingState.user,
                    setting: $store.settingState.setting,
                    blurRadius: store.appLockState.blurRadius,
                    tagTranslator: store.settingState.tagTranslator
                )
            }
            .accentColor(store.settingState.setting.accentColor)
            .autoBlur(radius: store.appLockState.blurRadius)
            .environment(\.inSheet, true)
            .navigationViewStyle(.stack)
        }
        .progressHUD(
            config: store.appRouteState.hudConfig,
            unwrapping: $store.appRouteState.route,
            case: /AppRouteReducer.Route.hud
        )
        .onChange(of: scenePhase) { _, newValue in store.send(.onScenePhaseChange(newValue)) }
        .onOpenURL { store.send(.appRoute(.handleDeepLink($0))) }
    }
}

// MARK: TabType
enum TabBarItemType: Int, CaseIterable, Identifiable {
    var id: Int { rawValue }

    case home
    case favorites
    case search
    case setting
}

extension TabBarItemType {
    var title: String {
        switch self {
        case .home:
            return L10n.Localizable.TabItem.Title.home
        case .favorites:
            return L10n.Localizable.TabItem.Title.favorites
        case .search:
            return L10n.Localizable.TabItem.Title.search
        case .setting:
            return L10n.Localizable.TabItem.Title.setting
        }
    }
    var symbol: SFSymbol {
        switch self {
        case .home:
            return .houseCircle
        case .favorites:
            return .heartCircle
        case .search:
            return .magnifyingglassCircle
        case .setting:
            return .gearshapeCircle
        }
    }
    func label() -> Label<Text, Image> {
        Label(title, systemSymbol: symbol)
    }
}

struct TabBarView_Previews: PreviewProvider {
    static var previews: some View {
        TabBarView(store: .init(initialState: .init(), reducer: AppReducer.init))
    }
}
