import AppComponents
import AppModels
import AppTools
import ComposableArchitecture
import DetailFeature
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI

/// Each folded pane owns its navigation bar, so the other pane's scroll cannot resize its title.
struct HomePrimaryNavigationView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable var store: StoreOf<HomeReducer>
    let showsSplitHome: Bool

    var body: some View {
        NavigationStack(path: $store.scope(\.path, action: \.path)) {
            HomeSectionsView(store: store, pane: showsSplitHome ? .left : nil)
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
            .toolbar {
                if !showsSplitHome {
                    HomeReloadToolbarItem(store: store)
                }
            }
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
                    HomeReloadToolbarItem(store: store)
                }
                .refreshable { await store.send(.fetchAllToplistsGalleries).finish() }
        }
    }
}

/// The refresh action belongs to all of Home; the outermost pane hosts its native toolbar item.
private struct HomeReloadToolbarItem: ToolbarContent {
    var store: StoreOf<HomeReducer>

    var body: some ToolbarContent {
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
