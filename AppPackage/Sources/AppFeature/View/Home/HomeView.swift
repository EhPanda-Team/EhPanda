import SwiftUI
import AppModels
import Resources
import Kingfisher
import SFSafeSymbols
import ComposableArchitecture

struct HomeView: View {
    @Bindable private var store: StoreOf<HomeReducer>
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: StoreOf<HomeReducer>,
        user: User, setting: Binding<Setting>, blurRadius: Double, tagTranslator: TagTranslator
    ) {
        self.store = store
        self.user = user
        _setting = setting
        self.blurRadius = blurRadius
        self.tagTranslator = tagTranslator
    }

    // MARK: HomeView
    var body: some View {
        NavigationView {
            let content =
                ZStack {
                    ScrollView(showsIndicators: false) {
                        VStack {
                            if !store.popularGalleries.isEmpty {
                                CardSlideSection(
                                    galleries: store.popularGalleries,
                                    pageIndex: $store.cardPageIndex,
                                    currentID: store.currentCardID,
                                    colors: store.cardColors,
                                    navigateAction: navigateTo(gid:),
                                    webImageSuccessAction: { gid, result in
                                        store.send(.analyzeImageColors(gid, result))
                                    }
                                )
                                .equatable().allowsHitTesting(store.allowsCardHitTesting)
                            }
                            Group {
                                if store.frontpageGalleries.count > 1 {
                                    CoverWallSection(
                                        galleries: store.frontpageGalleries,
                                        isLoading: store.frontpageLoadingState == .loading,
                                        navigateAction: navigateTo(gid:),
                                        showAllAction: { store.send(.setNavigation(.section(.frontpage))) },
                                        reloadAction: { store.send(.fetchFrontpageGalleries) }
                                    )
                                }
                                ToplistsSection(
                                    galleries: store.toplistsGalleries,
                                    isLoading: !store.toplistsLoadingState
                                        .values.allSatisfy({ $0 != .loading }),
                                    navigateAction: navigateTo(gid:),
                                    showAllAction: { store.send(.setNavigation(.section(.toplists))) },
                                    reloadAction: { store.send(.fetchAllToplistsGalleries) }
                                )
                                MiscGridSection(navigateAction: navigateTo(type:))
                            }
                            .padding(.vertical)
                        }
                    }
                    .opacity(store.popularGalleries.isEmpty ? 0 : 1).zIndex(2)

                    LoadingView()
                        .opacity(
                            store.popularLoadingState == .loading
                                && store.popularGalleries.isEmpty ? 1 : 0
                        )
                        .zIndex(0)

                    let error = store.popularLoadingState.failed
                    ErrorView(error: error ?? .unknown) {
                        store.send(.fetchAllGalleries)
                    }
                    .opacity(store.popularGalleries.isEmpty && error != nil ? 1 : 0)
                    .zIndex(1)
                }
                .animation(.default, value: store.popularLoadingState)
                .onAppear {
                    if store.popularGalleries.isEmpty {
                        store.send(.fetchAllGalleries)
                    }
                }
                .background(navigationLinks)
                .toolbar(content: toolbar)
                .navigationTitle(L10n.Localizable.HomeView.Title.home)

            if DeviceUtil.isPad {
                content
                    .sheet(item: $store.route.sending(\.setNavigation).detail, id: \.self) { route in
                        NavigationView {
                            DetailView(
                                store: store.scope(state: \.detailState.wrappedValue!, action: \.detail),
                                gid: route.wrappedValue, user: user, setting: $setting,
                                blurRadius: blurRadius, tagTranslator: tagTranslator
                            )
                        }
                        .autoBlur(radius: blurRadius).environment(\.inSheet, true).navigationViewStyle(.stack)
                    }
            } else {
                content
            }
        }
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem(tint: .primary) {
            Button {
                store.send(.fetchAllGalleries)
            } label: {
                Image(systemSymbol: .arrowCounterclockwise)
            }
            .opacity(store.popularLoadingState == .loading ? 0 : 1)
            .overlay(ProgressView().opacity(store.popularLoadingState == .loading ? 1 : 0))
        }
    }
}

// MARK: NavigationLinks
private extension HomeView {
    @ViewBuilder var navigationLinks: some View {
        if DeviceUtil.isPhone {
            detailViewLink
        }
        miscGridLink
        sectionLink
    }
    var detailViewLink: some View {
        NavigationLink(unwrapping: $store.route, case: \.detail) { route in
            DetailView(
                store: store.scope(state: \.detailState.wrappedValue!, action: \.detail),
                gid: route.wrappedValue, user: user, setting: $setting,
                blurRadius: blurRadius, tagTranslator: tagTranslator
            )
        }
    }
    var miscGridLink: some View {
        NavigationLink(unwrapping: $store.route, case: \.misc) { route in
            switch route.wrappedValue {
            case .popular:
                PopularView(
                    store: store.scope(state: \.popularState, action: \.popular),
                    user: user, setting: $setting, blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            case .watched:
                WatchedView(
                    store: store.scope(state: \.watchedState, action: \.watched),
                    user: user, setting: $setting, blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            case .history:
                HistoryView(
                    store: store.scope(state: \.historyState, action: \.history),
                    user: user, setting: $setting, blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            }
        }
    }
    var sectionLink: some View {
        NavigationLink(unwrapping: $store.route, case: \.section) { route in
            switch route.wrappedValue {
            case .frontpage:
                FrontpageView(
                    store: store.scope(state: \.frontpageState, action: \.frontpage),
                    user: user, setting: $setting, blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            case .toplists:
                ToplistsView(
                    store: store.scope(state: \.toplistsState, action: \.toplists),
                    user: user, setting: $setting, blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            }
        }
    }
    func navigateTo(gid: String) {
        store.send(.setNavigation(.detail(gid)))
    }
    func navigateTo(type: HomeMiscGridType) {
        store.send(.setNavigation(.misc(type)))
    }
}

// MARK: Definition
enum HomeMiscGridType: CaseIterable, Identifiable {
    var id: String { title }

    case popular
    case watched
    case history
}

extension HomeMiscGridType {
    var title: String {
        switch self {
        case .popular:
            return L10n.Localizable.Enum.HomeMiscGridType.Title.popular
        case .watched:
            return L10n.Localizable.Enum.HomeMiscGridType.Title.watched
        case .history:
            return L10n.Localizable.Enum.HomeMiscGridType.Title.history
        }
    }
    var symbol: SFSymbol {
        switch self {
        case .popular:
            return .flame
        case .watched:
            return .tagCircle
        case .history:
            return .clockArrowTriangleheadCounterclockwiseRotate90
        }
    }
}

enum HomeSectionType: String, CaseIterable, Identifiable {
    var id: String { rawValue }

    case frontpage
    case toplists
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView(
            store: .init(initialState: .init(), reducer: HomeReducer.init),
            user: .init(),
            setting: .constant(.init()),
            blurRadius: 0,
            tagTranslator: .init()
        )
    }
}
