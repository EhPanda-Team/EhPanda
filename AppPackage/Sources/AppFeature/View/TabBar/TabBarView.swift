import SwiftUI
import AppModels
import Resources
import SFSafeSymbols
import ComposableArchitecture
import Dependencies
import DeviceClient
import SystemNotificationExt
import AppComponents
import DetailFeature
import HomeFeature
import SearchFeature
import FavoritesFeature
import DownloadsFeature
import SettingFeature

struct TabBarView: View {
    @Dependency(\.deviceClient) private var deviceClient
    @Environment(\.scenePhase) private var scenePhase
    @Bindable private var store: StoreOf<AppReducer>

    init(store: StoreOf<AppReducer>) {
        self.store = store
    }

    var body: some View {
        TabView(
            selection: .init(
                get: { store.tabBarState.tabBarItemType },
                set: { tab in
                    if tab == .setting, deviceClient.deviceType() == .pad {
                        store.send(.appRoute(.presentSetting))
                    } else {
                        store.send(.tabBar(.setTabBarItemType(tab)))
                    }
                }
            )
        ) {
            ForEach(TabBarItemType.allCases) { type in
                Group {
                    switch type {
                    case .home:
                        HomeView(
                            store: store.scope(\.homeState, action: \.home)
                        )
                    case .favorites:
                        FavoritesView(
                            store: store.scope(\.favoritesState, action: \.favorites)
                        )
                    case .search:
                        SearchRootView(
                            store: store.scope(\.searchRootState, action: \.searchRoot),
                            blurRadius: 0
                        )
                    case .downloads:
                        DownloadsView(
                            store: store.scope(\.downloadsState, action: \.downloads),
                            blurRadius: 0
                        )
                    case .setting:
                        SettingView(
                            store: store.scope(\.settingState, action: \.setting),
                            blurRadius: 0
                        )
                    }
                }
                .tabItem(type.label).tag(type)
            }
            .accentColor(store.settingState.setting.accentColor)
        }
        .privacyMask()
        .sheet(item: $store.appRouteState.destination.newDawn) { greeting in
            NewDawnView(greeting: greeting.wrappedValue)
                .privacyMask()
        }
        .sheet(item: $store.appRouteState.destination.setting) { _ in
            SettingView(
                store: store.scope(\.settingState, action: \.setting),
                blurRadius: 0
            )
            .accentColor(store.settingState.setting.accentColor)
            .privacyMask()
        }
        .sheet(item: $store.scope(\.appRouteState.$detail, action: \.appRoute.detail)) { detailStore in
            NavigationStack(
                path: $store.scope(\.appRouteState.path, action: \.appRoute.path)
            ) {
                DetailView(
                    store: detailStore,
                    gid: detailStore.gid,
                    blurRadius: 0
                )
            } destination: { elementStore in
                galleryDestination(
                    elementStore,
                    blurRadius: 0
                )
            }
            .accentColor(store.settingState.setting.accentColor)
            .privacyMask()
            .environment(\.inSheet, true)
        }
        .toast($store.scope(\.appRouteState.$toast, action: \.appRoute.toast))
        .onChange(of: scenePhase) { _, newValue in store.send(.onScenePhaseChange(newValue)) }
        .onOpenURL { store.send(.appRoute(.handleDeepLink($0))) }
    }
}

// MARK: TabType
extension TabBarItemType {
    var title: LocalizedStringResource {
        switch self {
        case .home:
            return .RLocalizable.home
        case .favorites:
            return .RLocalizable.favorites
        case .search:
            return .RLocalizable.search
        case .downloads:
            return .RLocalizable.downloads
        case .setting:
            return .RLocalizable.setting
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
        case .downloads:
            return .arrowDownCircle
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
