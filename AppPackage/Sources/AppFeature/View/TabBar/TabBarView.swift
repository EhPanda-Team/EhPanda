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

    /// The bottom safe-area inset of the selected tab's content. On a bottom tab bar it includes the bar.
    @State private var selectedTabBottomInset: CGFloat = 0
    /// The bottom safe-area inset of the tab view itself, which never includes the tab bar.
    @State private var tabViewBottomInset: CGFloat = 0

    /// The height of the tab bar that lies over the bottom of the screen, which the root's toast keeps clear of
    /// (owner decision C3: the toast avoids a tab bar only where there is one, not on every screen).
    ///
    /// It is the difference between the two insets above: the tab view's own bottom inset is the device's, and the
    /// selected tab's content has the bar on top of it. It is 0 where no bar lies over the bottom, as under the
    /// iPad's top tab bar. It is computed from the two measured values, so there is one source and no copy to go
    /// stale. Each tab writes its inset only while it is selected, and the bar is the same for every tab.
    private var tabBarClearance: CGFloat {
        max(0, selectedTabBottomInset - tabViewBottomInset)
    }

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
            bottomClearance: tabBarClearance,
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
                    tabRoot(type)
                        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { inset in
                            if store.tabBarState.tabBarItemType == type {
                                selectedTabBottomInset = inset
                            }
                        }
                } label: {
                    Label(type.title, systemSymbol: type.symbol)
                }
            }
        }
        .onGeometryChange(for: CGFloat.self) { $0.safeAreaInsets.bottom } action: { tabViewBottomInset = $0 }
    }

    @ViewBuilder private func tabRoot(_ type: TabBarItemType) -> some View {
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
