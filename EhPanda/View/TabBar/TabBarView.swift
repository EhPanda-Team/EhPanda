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
    private let store: Store<AppState, AppAction>
    @ObservedObject private var viewStore: ViewStore<AppState, AppAction>

    init(store: Store<AppState, AppAction>) {
        self.store = store
        viewStore = ViewStore(store)
    }

    var body: some View {
        ZStack {
            TabView(selection: viewStore.binding(\.tabBarState.$tabBarItemType)) {
                ForEach(TabBarItemType.allCases) { type in
                    Group {
                        switch type {
                        case .home:
                            HomeView(
                                store: store.scope(state: \.homeState, action: AppAction.home),
                                user: viewStore.settingState.user,
                                setting: viewStore.settingState.setting,
                                blurRadius: viewStore.appLockState.blurRadius,
                                tagTranslator: viewStore.settingState.tagTranslator
                            )
                        case .favorites:
                            FavoritesView(
                                store: store.scope(state: \.favoritesState, action: AppAction.favorites),
                                user: viewStore.settingState.user, setting: viewStore.settingState.setting,
                                blurRadius: viewStore.appLockState.blurRadius,
                                tagTranslator: viewStore.settingState.tagTranslator
                            )
                        case .search:
                            SearchView(
                                store: store.scope(state: \.searchState, action: AppAction.search),
                                user: viewStore.settingState.user,
                                setting: viewStore.settingState.setting,
                                blurRadius: viewStore.appLockState.blurRadius,
                                tagTranslator: viewStore.settingState.tagTranslator
                            )
                        case .setting:
                            SettingView(
                                store: store.scope(state: \.settingState, action: AppAction.setting),
                                blurRadius: viewStore.appLockState.blurRadius
                            )
                        }
                    }
                    .tabItem(type.label).tag(type)
                }
                .accentColor(viewStore.settingState.setting.accentColor)
            }
            .autoBlur(radius: viewStore.appLockState.blurRadius)
            Image(systemSymbol: .lockFill).font(.system(size: 80))
                .opacity(viewStore.appLockState.isAppLocked ? 1 : 0)
        }
        .sheet(unwrapping: viewStore.binding(\.appRouteState.$route), case: /AppRouteState.Route.newDawn) { route in
            NewDawnView(greeting: route.wrappedValue)
                .autoBlur(radius: viewStore.appLockState.blurRadius)
        }
        .sheet(unwrapping: viewStore.binding(\.appRouteState.$route), case: /AppRouteState.Route.filters) { _ in
            FiltersView(
                store: store.scope(
                    state: \.appRouteState.filtersState, action: { AppAction.appRoute(.filters($0)) }
                ),
                searchFilter: viewStore.binding(\.settingState.$searchFilter),
                globalFilter: viewStore.binding(\.settingState.$globalFilter),
                watchedFilter: viewStore.binding(\.settingState.$watchedFilter)
            )
            .tint(viewStore.settingState.setting.accentColor)
            .accentColor(viewStore.settingState.setting.accentColor)
            .autoBlur(radius: viewStore.appLockState.blurRadius)
        }
        .sheet(unwrapping: viewStore.binding(\.appRouteState.$route), case: /AppRouteState.Route.detail) { route in
            NavigationView {
                DetailView(
                    store: store.scope(state: \.appRouteState.detailState, action: { AppAction.appRoute(.detail($0)) }),
                    gid: route.wrappedValue, user: viewStore.settingState.user, setting: viewStore.settingState.setting,
                    blurRadius: viewStore.appLockState.blurRadius, tagTranslator: viewStore.settingState.tagTranslator
                )
            }
            .accentColor(viewStore.settingState.setting.accentColor)
            .autoBlur(radius: viewStore.appLockState.blurRadius)
            .environment(\.isSheet, true)
        }
        .progressHUD(
            config: viewStore.appRouteState.hudConfig,
            unwrapping: viewStore.binding(\.appRouteState.$route),
            case: /AppRouteState.Route.hud
        )
        .onChange(of: scenePhase) { viewStore.send(.onScenePhaseChange($0)) }
        .onOpenURL { viewStore.send(.appRoute(.handleDeepLink($0))) }
    }
}

// MARK: TabType
enum TabBarItemType: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    case home = "Home"
    case favorites = "Favorites"
    case search = "Search"
    case setting = "Setting"
}

extension TabBarItemType {
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
        Label(rawValue.localized, systemSymbol: symbol)
    }
}

struct TabBarView_Previews: PreviewProvider {
    static var previews: some View {
        TabBarView(
            store: .init(
                initialState: .init(),
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
                    clipboardClient: .live,
                    appDelegateClient: .live,
                    userDefaultsClient: .live,
                    uiApplicationClient: .live,
                    authorizationClient: .live
                )
            )
        )
    }
}
