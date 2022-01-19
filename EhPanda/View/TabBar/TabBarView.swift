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
                                tagTranslator: viewStore.settingState.tagTranslator
                            )
                        case .favorites:
                            FavoritesView(
                                store: store.scope(state: \.favoritesState, action: AppAction.favorites),
                                user: viewStore.settingState.user, setting: viewStore.settingState.setting,
                                tagTranslator: viewStore.settingState.tagTranslator
                            )
                        case .search:
                            SearchView(
                                store: store.scope(state: \.searchState, action: AppAction.search),
                                user: viewStore.settingState.user,
                                setting: viewStore.settingState.setting,
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
            .blur(radius: viewStore.appLockState.blurRadius)
            .allowsHitTesting(viewStore.appLockState.blurRadius < 1)
            .animation(.linear(duration: 0.1), value: viewStore.appLockState.blurRadius)
            Image(systemSymbol: .lockFill).font(.system(size: 80))
                .opacity(viewStore.appLockState.isAppLocked ? 1 : 0)
        }
        .sheet(item: viewStore.binding(\.appSheetState.$sheetState)) { state in
            switch state {
            case .newDawn(let greeting):
                NewDawnView(greeting: greeting)
            case .filters:
                FiltersView(
                    store: store.scope(
                        state: \.appSheetState.filtersState, action: { AppAction.appSheet(.filters($0)) }
                    ),
                    searchFilter: viewStore.binding(\.settingState.$searchFilter),
                    globalFilter: viewStore.binding(\.settingState.$globalFilter),
                    watchedFilter: viewStore.binding(\.settingState.$watchedFilter)
                )
                .tint(viewStore.settingState.setting.accentColor)
                .accentColor(viewStore.settingState.setting.accentColor)
                .blur(radius: viewStore.appLockState.blurRadius)
                .allowsHitTesting(viewStore.appLockState.blurRadius < 1)
                .animation(.linear(duration: 0.1), value: viewStore.appLockState.blurRadius)
            }
        }
        .onChange(of: scenePhase) { newValue in
            viewStore.send(.onScenePhaseChange(newValue))
        }
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
