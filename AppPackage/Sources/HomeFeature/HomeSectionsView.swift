import AppComponents
import AppModels
import ComposableArchitecture
import SwiftUI

struct HomeSectionsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @GalleryCoverMetrics(.homeCompact) private var compactCoverSize
    @GalleryCoverMetrics(.hero) private var heroCoverSize
    @Bindable var store: StoreOf<HomeReducer>
    var pane: HomePane?
    @State private var viewport: CGSize = .zero

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
                showsRichInformation: pane == nil,
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
                showsRichInformation: true,
                maximumCoverHeight: maximumFrontpageCoverHeight,
                navigateAction: { store.send(.galleryTapped($0, from: .left)) },
                showAllAction: { store.send(.sectionTapped(.frontpage)) },
                reloadAction: { store.send(.fetchFrontpageGalleries) }
            )
        }
    }

    private var maximumFrontpageCoverHeight: CGFloat? {
        let galleryViewport = GalleryViewport(size: viewport, isRegularWidth: horizontalSizeClass == .regular)
        if pane != nil {
            return min(heroCoverSize.height, max(0, galleryViewport.maximumSlideshowHeight - 40))
        }
        return galleryViewport.isLarge ? nil : compactCoverSize.height
    }

    private var toplists: some View {
        ToplistsSection(
            galleries: store.toplistsGalleries,
            isLoading: !store.toplistsLoadingState.values.allSatisfy({ $0 != .loading }),
            stacksSixGalleries: store.usesSplitLayout,
            showsRichInformation: true,
            showsHeading: pane != .right,
            navigateAction: { store.send(.galleryTapped($0, from: .right)) },
            showAllAction: { store.send(.sectionTapped(.toplists)) },
            reloadAction: { store.send(.fetchAllToplistsGalleries) }
        )
    }

    private var other: some View {
        MiscGridSection(
            showsRichInformation: true,
            navigateAction: { store.send(.miscTapped($0)) }
        )
    }
}
