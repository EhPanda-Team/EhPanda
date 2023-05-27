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
    private let store: StoreOf<AppReducer>
    @ObservedObject private var viewStore: ViewStoreOf<AppReducer>

    init(store: StoreOf<AppReducer>) {
        self.store = store
        viewStore = ViewStore(store)
    }

    var body: some View {
        ZStack {
            TabView(
                selection: .init(
                    get: { viewStore.tabBarState.tabBarItemType },
                    set: { viewStore.send(.tabBar(.setTabBarItemType($0))) }
                )
            ) {
                ForEach(TabBarItemType.allCases) { type in
                    Group {
                        switch type {
                        case .home:
                            HomeView(
                                store: store.scope(state: \.homeState, action: AppReducer.Action.home),
                                user: viewStore.settingState.user,
                                setting: viewStore.binding(\.settingState.$setting),
                                blurRadius: viewStore.appLockState.blurRadius,
                                tagTranslator: viewStore.settingState.tagTranslator
                            )
                        case .favorites:
                            FavoritesView(
                                store: store.scope(state: \.favoritesState, action: AppReducer.Action.favorites),
                                user: viewStore.settingState.user,
                                setting: viewStore.binding(\.settingState.$setting),
                                blurRadius: viewStore.appLockState.blurRadius,
                                tagTranslator: viewStore.settingState.tagTranslator
                            )
                        case .search:
                            SearchRootView(
                                store: store.scope(state: \.searchRootState, action: AppReducer.Action.searchRoot),
                                user: viewStore.settingState.user,
                                setting: viewStore.binding(\.settingState.$setting),
                                blurRadius: viewStore.appLockState.blurRadius,
                                tagTranslator: viewStore.settingState.tagTranslator
                            )
                        case .setting:
                            SettingView(
                                store: store.scope(state: \.settingState, action: AppReducer.Action.setting),
                                blurRadius: viewStore.appLockState.blurRadius
                            )
                        }
                    }
                    .tabItem(type.label).tag(type)
                }
                .accentColor(viewStore.settingState.setting.accentColor)
            }
            .autoBlur(radius: viewStore.appLockState.blurRadius)
            Button {
                viewStore.send(.appLock(.authorize))
            } label: {
                Image(systemSymbol: .lockFill)
            }
            .font(.system(size: 80)).opacity(viewStore.appLockState.isAppLocked ? 1 : 0)
        }
        .sheet(unwrapping: viewStore.binding(\.appRouteState.$route), case: /AppRouteReducer.Route.newDawn) { route in
            NewDawnView(greeting: route.wrappedValue)
                .autoBlur(radius: viewStore.appLockState.blurRadius)
        }
        .sheet(unwrapping: viewStore.binding(\.appRouteState.$route), case: /AppRouteReducer.Route.setting) { _ in
            SettingView(
                store: store.scope(state: \.settingState, action: AppReducer.Action.setting),
                blurRadius: viewStore.appLockState.blurRadius
            )
            .accentColor(viewStore.settingState.setting.accentColor)
            .autoBlur(radius: viewStore.appLockState.blurRadius)
        }
        .sheet(unwrapping: viewStore.binding(\.appRouteState.$route), case: /AppRouteReducer.Route.detail) { route in
            NavigationView {
                DetailView(
                    store: store.scope(
                        state: \.appRouteState.detailState,
                        action: { AppReducer.Action.appRoute(.detail($0)) }
                    ),
                    gid: route.wrappedValue, user: viewStore.settingState.user,
                    setting: viewStore.binding(\.settingState.$setting),
                    blurRadius: viewStore.appLockState.blurRadius,
                    tagTranslator: viewStore.settingState.tagTranslator
                )
            }
            .accentColor(viewStore.settingState.setting.accentColor)
            .autoBlur(radius: viewStore.appLockState.blurRadius)
            .environment(\.inSheet, true)
            .navigationViewStyle(.stack)
        }
        .progressHUD(
            config: viewStore.appRouteState.hudConfig,
            unwrapping: viewStore.binding(\.appRouteState.$route),
            case: /AppRouteReducer.Route.hud
        )
        .onChange(of: scenePhase) { viewStore.send(.onScenePhaseChange($0)) }
        .onOpenURL { viewStore.send(.appRoute(.handleDeepLink($0))) }
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
        TabBarView(
            store: .init(
                initialState: .init(),
                reducer: AppReducer()
            )
        )
    }
}
