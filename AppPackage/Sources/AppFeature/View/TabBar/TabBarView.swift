import SwiftUI
import AppModels
import Resources
import SFSafeSymbols
import ComposableArchitecture
import Dependencies
import DeviceClient
import SystemNotification
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
                        store.send(.presentation(.presentSetting))
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
                            store: store.scope(\.searchRootState, action: \.searchRoot)
                        )
                    case .downloads:
                        DownloadsView(
                            store: store.scope(\.downloadsState, action: \.downloads)
                        )
                    case .setting:
                        SettingView(
                            store: store.scope(\.settingState, action: \.setting)
                        )
                    }
                }
                .tabItem(type.label).tag(type)
            }
        }
        .privacyMask()
        .sheet(item: $store.presentationState.destination.newDawn) { greeting in
            NewDawnView(greeting: greeting.wrappedValue)
                .privacyMask()
        }
        .sheet(item: $store.presentationState.destination.errorInfo) { errorInfo in
            ErrorInfoView(errorInfo: errorInfo.wrappedValue)
                .privacyMask()
        }
        .sheet(item: $store.presentationState.destination.setting) { _ in
            SettingView(
                store: store.scope(\.settingState, action: \.setting)
            )
            .privacyMask()
        }
        .sheet(item: $store.scope(\.presentationState.$detail, action: \.presentation.detail)) { detailStore in
            NavigationStack(
                path: $store.scope(\.presentationState.path, action: \.presentation.path)
            ) {
                DetailView(
                    store: detailStore,
                    gid: detailStore.gid
                )
            } destination: { elementStore in
                galleryDestination(elementStore)
            }
            .privacyMask()
        }
        .toast(
            $store.scope(\.presentationState.$toast, action: \.presentation.toast),
            onErrorTap: { errorInfo in
                store.send(.presentation(.presentErrorInfo(errorInfo)))
            }
        )
        .onChange(of: scenePhase) { _, newValue in store.send(.onScenePhaseChange(newValue)) }
        .onOpenURL { store.send(.presentation(.handleDeepLink($0))) }
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

#Preview("Initial") {
    TabBarView(store: .init(initialState: .init(), reducer: AppReducer.init))
}
