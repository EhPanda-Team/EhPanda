import SwiftUI
import AppModels
import Resources
import Kingfisher
import SFSafeSymbols
import ComposableArchitecture
import AppTools
import AppComponents
import SFSafeSymbolsExt
import DetailFeature

public struct HomeView: View {
    @Bindable private var store: StoreOf<HomeReducer>

    public init(store: StoreOf<HomeReducer>) {
        self.store = store
    }

    // MARK: HomeView
    public var body: some View {
        NavigationStack(path: $store.scope(\.path, action: \.path)) {
            ScrollView(showsIndicators: false) {
                VStack {
                    Group {
                        if !store.popularGalleries.isEmpty {
                            CardSlideSection(
                                galleries: store.popularGalleries,
                                pageIndex: $store.cardPageIndex,
                                currentID: store.currentCardID,
                                colors: store.cardColors,
                                navigateAction: navigateTo(gallery:),
                                webImageSuccessAction: { gid, result in
                                    store.send(.analyzeImageColors(gid, result))
                                }
                            )
                            .equatable().allowsHitTesting(store.allowsCardHitTesting)
                        }
                        if store.frontpageGalleries.count > 1 {
                            CoverWallSection(
                                galleries: store.frontpageGalleries,
                                isLoading: store.frontpageLoadingState == .loading,
                                navigateAction: navigateTo(gallery:),
                                showAllAction: { store.send(.sectionTapped(.frontpage)) },
                                reloadAction: { store.send(.fetchFrontpageGalleries) }
                            )
                        }
                        ToplistsSection(
                            galleries: store.toplistsGalleries,
                            isLoading: !store.toplistsLoadingState
                                .values.allSatisfy({ $0 != .loading }),
                            navigateAction: navigateTo(gallery:),
                            showAllAction: { store.send(.sectionTapped(.toplists)) },
                            reloadAction: { store.send(.fetchAllToplistsGalleries) }
                        )
                        MiscGridSection(navigateAction: navigateTo(type:))
                    }
                    .padding(.vertical)
                }
            }
            .animation(.default) {
                $0.opacity(store.popularGalleries.isEmpty ? 0 : 1)
            }
            .opacity(store.popularGalleries.isEmpty ? 0 : 1)
            .animation(.default, value: store.popularLoadingState)
            .overlay {
                LoadingView()
                    .animation(.default) {
                        $0.opacity(
                            store.popularLoadingState == .loading
                                && store.popularGalleries.isEmpty ? 1 : 0
                        )
                    }
            }
            .overlay {
                let error = store.popularLoadingState.failed
                ErrorView(error: error ?? .unknown) {
                    store.send(.fetchAllGalleries)
                }
                .animation(.default) {
                    $0.opacity(store.popularGalleries.isEmpty && error != nil ? 1 : 0)
                }
                .opacity(store.popularGalleries.isEmpty && error != nil ? 1 : 0)
            }
            .onAppear {
                if store.popularGalleries.isEmpty {
                    store.send(.fetchAllGalleries)
                }
            }
            .toolbarTitleDisplayMode(.inlineLarge)
            .navigationTitle(.RLocalizable.home)
            .toolbar(content: toolbar)
        } destination: { store in
            switch store.case {
            case .frontpage(let store):
                FrontpageView(store: store)
            case .popular(let store):
                PopularView(store: store)
            case .toplists(let store):
                ToplistsView(store: store)
            case .watched(let store):
                WatchedView(store: store)
            case .history(let store):
                HistoryView(store: store)
            case .gallery(let store):
                galleryDestination(store)
            }
        }
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            Button {
                store.send(.fetchAllGalleries)
            } label: {
                Label(.reload, systemSymbol: .arrowCounterclockwise)
            }
            .opacity(store.popularLoadingState == .loading ? 0 : 1)
            .overlay(ProgressView().opacity(store.popularLoadingState == .loading ? 1 : 0))
        }
    }
}

// MARK: Navigation
private extension HomeView {
    func navigateTo(gallery: Gallery) {
        store.send(.galleryTapped(gallery))
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

#Preview("Initial") {
    HomeView(
        store: .init(
            initialState: {
                var state = HomeReducer.State()
                let popular = Gallery.previews(count: 5)
                state.popularGalleries = popular
                state.currentCardID = popular.first?.id ?? ""
                state.frontpageGalleries = Gallery.previews(count: 4)
                return state
            }(),
            reducer: HomeReducer.init
        )
    )
}
