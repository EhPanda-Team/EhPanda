import SwiftUI
import AppModels
import Resources
import Kingfisher
import SFSafeSymbols
import ComposableArchitecture
import AppTools
import AppComponents
import DetailFeature

public struct HomeView: View {
    @Bindable private var store: StoreOf<HomeReducer>
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    public init(
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
    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
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
                                    showAllAction: { store.send(.sectionTapped(.frontpage)) },
                                    reloadAction: { store.send(.fetchFrontpageGalleries) }
                                )
                            }
                            ToplistsSection(
                                galleries: store.toplistsGalleries,
                                isLoading: !store.toplistsLoadingState
                                    .values.allSatisfy({ $0 != .loading }),
                                navigateAction: navigateTo(gid:),
                                showAllAction: { store.send(.sectionTapped(.toplists)) },
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
            .toolbar(content: toolbar)
            .navigationTitle(.RLocalizable.home)
        } destination: { store in
            switch store.case {
            case .frontpage(let store):
                FrontpageView(
                    store: store, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            case .popular(let store):
                PopularView(
                    store: store, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            case .toplists(let store):
                ToplistsView(
                    store: store, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            case .watched(let store):
                WatchedView(
                    store: store, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            case .history(let store):
                HistoryView(
                    store: store, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            case .gallery(let store):
                galleryDestination(
                    store, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
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

// MARK: Navigation
private extension HomeView {
    func navigateTo(gid: String) {
        store.send(.galleryTapped(gid))
    }
    func navigateTo(type: HomeMiscGridType) {
        store.send(.miscTapped(type))
    }
}

// MARK: Definition
public enum HomeMiscGridType: CaseIterable, Identifiable, Sendable {
    public var id: String { String(localized: title) }

    case popular
    case watched
    case history
}

extension HomeMiscGridType {
    var title: LocalizedStringResource {
        switch self {
        case .popular:
            return .homeMiscGridTypePopular
        case .watched:
            return .homeMiscGridTypeWatched
        case .history:
            return .homeMiscGridTypeHistory
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

public enum HomeSectionType: String, CaseIterable, Identifiable, Sendable {
    public var id: String { rawValue }

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
