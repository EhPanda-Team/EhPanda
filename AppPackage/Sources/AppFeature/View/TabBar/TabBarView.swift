import AppComponents
import AppModels
import ComposableArchitecture
import Dependencies
import DetailFeature
import DownloadsFeature
import FavoritesFeature
import HomeFeature
import Resources
import SearchFeature
import SettingFeature
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI
import SystemNotification

struct TabBarView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.verticalSizeClass) private var verticalSizeClass
    @Bindable private var store: StoreOf<AppReducer>

    init(store: StoreOf<AppReducer>) {
        self.store = store
    }

    var body: some View {
        Group {
            if #available(iOS 27.1, *) {
                tabs.toolbarVerticalCompressionBehavior(.prefersToolbarItems)
            } else {
                tabs
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
        .sheet(
            item: $store.scope(\.presentationState.$gallery, action: \.presentation.gallery),
            onDismiss: { store.send(.presentation(.detailDismissalCompleted)) }
        ) { galleryStore in
            GallerySheetView(store: galleryStore)
            .privacyMask()
        }
        .toast(
            $store.scope(\.presentationState.$toast, action: \.presentation.toast),
            onErrorTap: { errorInfo in
                store.send(.presentation(.presentErrorInfo(errorInfo)))
            }
        )
        .onChange(of: scenePhase) { _, newValue in
            store.send(.onScenePhaseChange(newValue))
        }
        .onChange(
            of: WindowSizeClasses(horizontal: horizontalSizeClass, vertical: verticalSizeClass),
            initial: true
        ) { _, newValue in
            store.send(.windowSizeClassesChanged(newValue))
        }
        .onOpenURL { store.send(.presentation(.handleDeepLink($0))) }
    }

    @ViewBuilder private var tabs: some View {
        @Bindable var tabBarStore = store.scope(\.tabBarState, action: \.tabBar)

        TabView(selection: $tabBarStore.tabBarItemType.sending(\.setTabBarItemType)) {
            ForEach(TabBarItemType.allCases) { type in
                Tab(value: type) {
                    switch type {
                    case .home:
                        HomeView(
                            store: store.scope(\.homeState, action: \.home)
                        )
                    case .library:
                        LibraryView(
                            store: store.scope(\.libraryState, action: \.library),
                            favoritesStore: store.scope(\.favoritesState, action: \.favorites),
                            downloadsStore: store.scope(\.downloadsState, action: \.downloads)
                        )
                    case .search:
                        SearchRootView(
                            store: store.scope(\.searchRootState, action: \.searchRoot)
                        )
                    case .setting:
                        SettingView(
                            store: store.scope(\.settingState, action: \.setting)
                        )
                    }
                } label: {
                    Label(type.title, systemSymbol: type.symbol)
                }
            }
        }
    }
}

// MARK: TabType
extension TabBarItemType {
    var title: LocalizedStringResource {
        switch self {
        case .home:
            return .RLocalizable.home
        case .library:
            return .RLocalizable.library
        case .search:
            return .RLocalizable.search
        case .setting:
            return .RLocalizable.setting
        }
    }
    var symbol: SFSymbol {
        switch self {
        case .home:
            return .houseCircle
        case .library:
            return .booksVerticalCircle
        case .search:
            return .magnifyingglassCircle
        case .setting:
            return .gearshapeCircle
        }
    }
}

#Preview("Initial") {
    TabBarView(store: .init(initialState: .init(), reducer: AppReducer.init))
}
