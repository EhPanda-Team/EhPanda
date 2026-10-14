import AppComponents
import ComposableArchitecture
import DetailFeature
import Resources
import SFSafeSymbols
import SwiftUI

/// Each folded pane owns its navigation bar, so the other pane's scroll cannot resize its title.
struct HomePrimaryNavigationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var store: StoreOf<HomeReducer>

    var body: some View {
        NavigationStack(path: $store.scope(\.path, action: \.path)) {
            HomeSectionsView(store: store, pane: store.usesDuoSplitLayout ? .left : nil)
            .animation(.default) {
                $0.visible(!store.popularGalleries.isEmpty)
            }
            // Keyed on the loading state, this animates the scroll content only (the overlays are
            // attached after it): `fetchPopularGalleriesDone` settles the state and lands the
            // galleries in one action, so what it drives is the card section's insertion, which
            // pushes the sections below it down — position motion, instant under Reduce Motion
            // (D-29). The whole-content fade above and the overlays' fades are crossfades and stay.
            .animation(reduceMotion ? nil : .default, value: store.popularLoadingState)
            .overlay {
                LoadingView()
                    .animation(.default) {
                        $0.visible(
                            store.popularLoadingState == .loading
                                && store.popularGalleries.isEmpty
                        )
                    }
            }
            .overlay {
                let error = store.popularLoadingState.failed
                ErrorView(error: error ?? .unknown) {
                    store.send(.fetchAllGalleries)
                }
                .animation(.default) {
                    $0.visible(store.popularGalleries.isEmpty && error != nil)
                }
            }
            .toolbarTitleDisplayMode(.inlineLarge)
            .navigationTitle(.RLocalizable.home)
            .toolbar { reloadItem }
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
        .modifier(HomePaneToolbarLayout())
    }

    private var reloadItem: some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                store.send(.fetchAllGalleries)
            } label: {
                Label(.reload, systemSymbol: .arrowCounterclockwise)
            }
            .visible(store.popularLoadingState != .loading)
            .overlay(ProgressView().visible(store.popularLoadingState == .loading))
        }
    }
}

struct HomeToplistsNavigationView: View {
    @Bindable var store: StoreOf<HomeReducer>

    var body: some View {
        NavigationStack {
            HomeSectionsView(store: store, pane: .right)
                .toolbarTitleDisplayMode(.inlineLarge)
                .navigationTitle(.toplists)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(.showAll) { store.send(.sectionTapped(.toplists)) }
                    }
                }
                .refreshable { await store.send(.fetchAllToplistsGalleries).finish() }
        }
        .modifier(HomePaneToolbarLayout())
    }
}

/// Each pane keeps its own navigation controls, including the native Back button, above its content.
private struct HomePaneToolbarLayout: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 27.1, *) {
            content.toolbarVerticalBehavior(.disabled)
        } else {
            content
        }
    }
}
