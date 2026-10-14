import AppComponents
import AppModels
import AppTools
public import ComposableArchitecture
import DetailFeature
import Kingfisher
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
public import SwiftUI

public struct HomeView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Bindable private var store: StoreOf<HomeReducer>
    @State private var viewportSize: CGSize = .zero

    public init(store: StoreOf<HomeReducer>) {
        self.store = store
    }

    // MARK: HomeView
    public var body: some View {
        NavigationStack(path: $store.scope(\.path, action: \.path)) {
            HomeSectionsView(store: store)
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
        .onVisibleViewportChange { viewportSize = $0 }
        .modifier(HomeHingeObservation { store.send(.hingeChanged(isPartiallyOpen: $0)) })
        .background {
            @UIBindable var presentationStore = store
            HomePaneSheet(
                item: $presentationStore.scope(\.$sheet, action: \.sheet),
                viewport: viewportSize,
                isPartiallyOpen: store.isPartiallyOpen,
                side: { $0.side },
                onDismiss: { store.send(.sheetDismissed) }
            ) { sheetStore in
                HomeSheetView(store: sheetStore, viewport: viewportSize, isPartiallyOpen: store.isPartiallyOpen)
            }
        }
    }

    private func toolbar() -> some ToolbarContent {
        ToolbarItemGroup(placement: .topBarTrailing) {
            Button {
                store.send(.fetchAllGalleries)
            } label: {
                Label(.reload, systemSymbol: .arrowCounterclockwise)
            }
            .visible(store.popularLoadingState != .loading)
            .overlay {
                ProgressView().visible(store.popularLoadingState == .loading)
            }
        }
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
