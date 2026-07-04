import SwiftUI
import AppModels
import Resources
import SFSafeSymbols
import ComposableArchitecture
import AppTools
import SystemNotificationExt
import AppComponents
import DetailFeature
import HomeFeature
import SearchFeature
import FavoritesFeature
import DownloadsFeature
import SettingFeature

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
                    set: { tab in
                        if tab == .setting, DeviceUtil.isPad {
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
                        case .downloads:
                            DownloadsView(
                                store: store.scope(state: \.downloadsState, action: \.downloads),
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
        .sheet(item: $store.appRouteState.destination.newDawn) { greeting in
            NewDawnView(greeting: greeting.wrappedValue)
                .autoBlur(radius: store.appLockState.blurRadius)
        }
        .sheet(item: $store.appRouteState.destination.setting) { _ in
            SettingView(
                store: store.scope(state: \.settingState, action: \.setting),
                blurRadius: store.appLockState.blurRadius
            )
            .accentColor(store.settingState.setting.accentColor)
            .autoBlur(radius: store.appLockState.blurRadius)
        }
        .sheet(item: $store.scope(state: \.appRouteState.detail, action: \.appRoute.detail)) { detailStore in
            NavigationStack(
                path: $store.scope(state: \.appRouteState.path, action: \.appRoute.path)
            ) {
                DetailView(
                    store: detailStore,
                    gid: detailStore.gid,
                    user: store.settingState.user,
                    setting: $store.settingState.setting,
                    blurRadius: store.appLockState.blurRadius,
                    tagTranslator: store.settingState.tagTranslator
                )
            } destination: { elementStore in
                galleryDestination(
                    elementStore,
                    user: store.settingState.user,
                    setting: $store.settingState.setting,
                    blurRadius: store.appLockState.blurRadius,
                    tagTranslator: store.settingState.tagTranslator
                )
            }
            .accentColor(store.settingState.setting.accentColor)
            .autoBlur(radius: store.appLockState.blurRadius)
            .environment(\.inSheet, true)
        }
        .toast($store.scope(state: \.appRouteState.toast, action: \.appRoute.toast))
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
