import AppComponents
import AppModels
import ComposableArchitecture
import SwiftUI

struct HomeSectionsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Bindable var store: StoreOf<HomeReducer>
    var pane: HomePane?
    @State private var viewport: CGSize = .zero

    private var showsRichInformation: Bool {
        pane == nil && GalleryViewport(
            size: viewport, isRegularWidth: horizontalSizeClass == .regular
        ).isLarge
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack {
                if pane != .right {
                    slideshow.padding(.vertical)
                    frontpage.padding(.vertical)
                }
                if pane != .left {
                    toplists.padding(.vertical)
                }
                if pane != .right {
                    other.padding(.vertical)
                }
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .onVisibleViewportChange { viewport = $0 }
        .accessibilityIdentifier(
            pane == .left ? "home_left_pane" : pane == .right ? "home_right_pane" : "home_sections"
        )
    }

    @ViewBuilder
    private var slideshow: some View {
        if !store.popularGalleries.isEmpty {
            CardSlideSection(
                galleries: store.popularGalleries,
                pageIndex: $store.cardPageIndex,
                currentID: store.currentCardID,
                colors: store.cardColors,
                carouselSize: viewport,
                showsRichInformation: showsRichInformation,
                maximumCardHeight: GalleryViewport(
                    size: viewport, isRegularWidth: horizontalSizeClass == .regular
                ).maximumSlideshowHeight,
                navigateAction: { store.send(.galleryTapped($0, from: .left)) },
                webImageSuccessAction: { gid, result in
                    store.send(.analyzeImageColors(gid: gid, result: result))
                }
            )
            .equatable()
            .allowsHitTesting(store.allowsCardHitTesting)
        }
    }

    @ViewBuilder
    private var frontpage: some View {
        if store.frontpageGalleries.count > 1 {
            CoverWallSection(
                galleries: store.frontpageGalleries,
                isLoading: store.frontpageLoadingState == .loading,
                showsRichInformation: showsRichInformation,
                navigateAction: { store.send(.galleryTapped($0, from: .left)) },
                showAllAction: { store.send(.sectionTapped(.frontpage)) },
                reloadAction: { store.send(.fetchFrontpageGalleries) }
            )
        }
    }

    private var toplists: some View {
        ToplistsSection(
            galleries: store.toplistsGalleries,
            isLoading: !store.toplistsLoadingState.values.allSatisfy({ $0 != .loading }),
            stacksSixGalleries: store.usesSplitLayout,
            showsRichInformation: showsRichInformation,
            showsHeading: pane != .right,
            navigateAction: { store.send(.galleryTapped($0, from: .right)) },
            showAllAction: { store.send(.sectionTapped(.toplists)) },
            reloadAction: { store.send(.fetchAllToplistsGalleries) }
        )
    }

    private var other: some View {
        MiscGridSection(
            showsRichInformation: showsRichInformation,
            navigateAction: { store.send(.miscTapped($0)) }
        )
    }
}
