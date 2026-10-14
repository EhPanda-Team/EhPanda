import AppComponents
import ComposableArchitecture
import SwiftUI

struct HomeSectionsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Environment(\.layoutDirection) private var layoutDirection
    @Bindable var store: StoreOf<HomeReducer>
    @State private var viewport: CGSize = .zero
    @State private var paneWidths: HomePaneWidths?

    var body: some View {
        if store.isPartiallyOpen {
            HStack(alignment: .top, spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack {
                        slideshow.padding(.vertical)
                        frontpage.padding(.vertical)
                        other.padding(.vertical)
                    }
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
                .frame(width: paneWidths?.left)
                .onVisibleViewportChange { viewport = $0 }
                .environment(\.layoutDirection, layoutDirection)
                .accessibilityIdentifier("home_left_pane")

                ScrollView(showsIndicators: false) {
                    toplists.padding(.vertical)
                }
                .scrollEdgeEffectStyle(.soft, for: .top)
                .frame(maxWidth: .infinity)
                .environment(\.layoutDirection, layoutDirection)
                .accessibilityIdentifier("home_right_pane")
            }
            .onGeometryChange(for: HomePaneWidths.self) { geometry in
                HomePaneWidths(
                    contentWidth: geometry.size.width,
                    leftInset: geometry.safeAreaInsets.leading,
                    rightInset: geometry.safeAreaInsets.trailing
                )
            } action: { paneWidths = $0 }
            // The two panes follow the physical fold; text within each keeps its own reading direction.
            .environment(\.layoutDirection, .leftToRight)
        } else {
            ScrollView(showsIndicators: false) {
                VStack {
                    slideshow.padding(.vertical)
                    frontpage.padding(.vertical)
                    toplists.padding(.vertical)
                    other.padding(.vertical)
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onVisibleViewportChange { viewport = $0 }
        }
    }

    @ViewBuilder
    private var slideshow: some View {
        if !store.popularGalleries.isEmpty {
            CardSlideSection(
                galleries: store.popularGalleries,
                pageIndex: $store.cardPageIndex,
                currentID: store.currentCardID,
                colors: store.cardColors,
                carouselWidth: viewport.width,
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
            stacksSixGalleries: store.isPartiallyOpen,
            navigateAction: { store.send(.galleryTapped($0, from: .right)) },
            showAllAction: { store.send(.sectionTapped(.toplists)) },
            reloadAction: { store.send(.fetchAllToplistsGalleries) }
        )
    }

    private var other: some View {
        MiscGridSection(navigateAction: { store.send(.miscTapped($0)) })
    }
}

/// The system can reserve an entire side for vertical bars. Split the enclosing width before
/// removing each side's own inset so that the divider stays on the fold as the bars minimize.
struct HomePaneWidths: Equatable {
    let contentWidth: CGFloat
    let leftInset: CGFloat
    let rightInset: CGFloat

    var left: CGFloat {
        min(contentWidth, max(0, (contentWidth + leftInset + rightInset) / 2 - leftInset))
    }
}
