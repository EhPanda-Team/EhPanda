import AppComponents
import AppModels
import AppTools
import Dependencies
import DeviceClient
import Kingfisher
import Resources
import SFSafeSymbols
import SwiftUI

// Sliding-window sizing for the carousel's infinite loop: `bufferedCards` exposes
// `windowBlocks` concatenated copies of the gallery list, and every settle rebases the
// window so the settled card sits back in `middleBlock`. Rebasing is only safe at
// `.idle` — while a scroll is in flight the content offset is pinned, so any mid-flight
// window shift makes `scrollPosition(id:)` re-derive its id by the same shift and the
// rebase re-triggers itself, endlessly (sim-measured). The width therefore carries the
// whole burst budget: chained flicks that never let the scroll settle consume headroom
// that only an `.idle` can restore. With `limitBehavior: .always` capping each gesture
// at one card, seven blocks of headroom per side means only a 40+-flick chain with zero
// pauses could ever reach the window edge — and a single natural pause resets it all.
private let windowBlocks = 15
private let middleBlock = windowBlocks / 2

// MARK: CardSlideSection
struct CardSlideSection: View, Equatable {
    @State private var scrollPositionID: Int?
    @State private var carouselWidth: CGFloat = 0
    // Last phase `onScrollPhaseChange` reported. Read by the handoff below to tell VoiceOver's own
    // scrolling (which produces no phase, so the phase stays `.idle`) from a gesture-driven one.
    @State private var scrollPhase: ScrollPhase = .idle
    // Origin of the sliding id window (see `bufferedCards`). Only ever shifted by whole
    // blocks (multiples of `galleries.count`), so a card's logical index is invariant
    // under rebase whether derived from its id or from its layout slot.
    @State private var windowBase = 0
    @Binding private var pageIndex: Int

    private let galleries: [Gallery]
    private let currentID: String
    private let colors: [Color]
    private let maximumCardHeight: CGFloat
    private let navigateAction: (Gallery) -> Void
    private let webImageSuccessAction: (String, RetrieveImageResult) -> Void

    init(
        galleries: [Gallery], pageIndex: Binding<Int>, currentID: String,
        colors: [Color], maximumCardHeight: CGFloat,
        navigateAction: @escaping (Gallery) -> Void,
        webImageSuccessAction: @escaping (String, RetrieveImageResult) -> Void
    ) {
        self.galleries = galleries
        _pageIndex = pageIndex
        self.currentID = currentID
        self.colors = colors
        self.maximumCardHeight = maximumCardHeight
        self.navigateAction = navigateAction
        self.webImageSuccessAction = webImageSuccessAction
        // Seed the initial position to the MIDDLE block's entry for the inbound page index
        // (`Page.withIndex` parity: `cardPageIndex` defaults to 1, so the carousel must not open
        // on the first card), giving the loop headroom on both sides from the first frame.
        let seedIndex = galleries.isEmpty ? nil : min(max(pageIndex.wrappedValue, 0), galleries.count - 1)
        _scrollPositionID = State(initialValue: seedIndex.map({ galleries.count * middleBlock + $0 }))
    }

    static func == (lhs: CardSlideSection, rhs: CardSlideSection) -> Bool {
        lhs.galleries == rhs.galleries
            && lhs.currentID == rhs.currentID
            && lhs.colors == rhs.colors
            && lhs.maximumCardHeight == rhs.maximumCardHeight
    }

    // A sliding window over an unbounded integer id space replaces `.loopPages()`: the window
    // shows `windowBlocks` concatenated copies of `galleries`, with `id % count` picking the
    // gallery. When a scroll settles outside the middle block, the window REBASES: `windowBase`
    // shifts by whole blocks so the settled id is back in the middle. Only the ForEach data
    // changes — `scrollPosition(id:)` keeps the settled view pinned across the content diff and
    // `scrollPositionID` is never written during scrolling — so the focused card's view identity
    // (and its gradient playback) survives every wrap, and no programmatic scroll can cancel an
    // in-flight gesture. There are exactly two bounded exceptions, and both write only while no
    // scroll is in flight: a gallery-count change, which invalidates the id space and requires the
    // synchronization write in `body` below; and the `.idle` anchor sync in the nearest-center
    // handoff, which re-anchors on the card VoiceOver has already scrolled to (see there for why a
    // VoiceOver scroll leaves the anchor stale). Neither animates and neither moves the content.
    private struct BufferedCard: Identifiable, Equatable {
        let id: Int
        let gallery: Gallery
    }

    private var bufferedCards: [BufferedCard] {
        let count = galleries.count
        guard count > 0 else { return [] }
        return (windowBase..<windowBase + count * windowBlocks).map { id in
            BufferedCard(id: id, gallery: galleries[logicalIndex(of: id)])
        }
    }

    // The ids of the block the rebase keeps the settled card in. Empty while there are no
    // galleries, which is also when `bufferedCards` is empty, so nothing is ever tested against it.
    private var middleBlockIDs: Range<Int> {
        let count = galleries.count
        return windowBase + count * middleBlock..<windowBase + count * (middleBlock + 1)
    }

    // Positive modulo: window ids run below zero after enough backward loops.
    private func logicalIndex(of id: Int) -> Int {
        let count = galleries.count
        return ((id % count) + count) % count
    }

    var body: some View {
        // The card geometry is container-driven (`cardWidth`/`centeringMargin` derive from
        // `carouselWidth`), and the measurement lands one layout pass AFTER the measured view's
        // first layout. If the ScrollView were laid out during that zero-width first pass, the
        // seeded `scrollPosition(id:)` anchor would resolve against collapsed content and the
        // carousel would open off the seeded card — visibly, the focused-card gradient sits on
        // the seeded card while its NEIGHBOR is centered until the first swipe reconciles them.
        // Deferring the ScrollView until the width is known makes its first layout the real one,
        // so the seed anchors correctly (matching the fixed-size construct the loop shipped with).
        Group {
            if carouselWidth > 0 && maximumCardHeight > 0 {
                carousel
            } else {
                Color.clear
            }
        }
        .onGeometryChange(for: CGFloat.self, of: \.size.width) {
            carouselWidth = $0
        }
    }

    private var carousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: cardSpacing) {
                ForEach(bufferedCards) { item in
                    card(for: item.gallery)
                        // One pass of the galleries for assistive technologies. The window carries
                        // `windowBlocks` copies of the list, and every copy the lazy stack builds is
                        // an accessibility element, so linear VoiceOver navigation reads the same
                        // galleries over and over and never leaves the carousel for the Frontpage
                        // heading. Exposing only the middle block leaves one pass, and the `.idle`
                        // rebase already keeps the centred card in that block, so whatever is on
                        // screen is always among the six. This is the same form `visible(_:)` uses
                        // (`AppComponents/ViewModifiers.swift`): the value is applied through
                        // `isEnabled:` rather than as `accessibilityHidden(false)`, because an
                        // explicit `false` is an *un*-hide that would re-expose whatever a
                        // descendant had hidden, not an absence of opinion (Phase 16 VO-2).
                        .accessibilityHidden(true, isEnabled: !middleBlockIDs.contains(item.id))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .scrollTargetLayout()
        }
        // `limitBehavior: .always` caps a gesture at one card — SwiftUIPager parity (the old
        // `Pager` had no `.multiplePagination()`, so it paged one card per swipe) AND the cap
        // that makes the sliding window's edge unreachable: without it, a violent flick's
        // deceleration alone traverses several cards and chained flicks ran 40+ cards past
        // every settle (sim-measured), clamping at the window edge before any `.idle` rebase.
        .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
        .fixedSize(horizontal: false, vertical: true)
        .scrollPosition(id: $scrollPositionID)
        .contentMargins(.horizontal, centeringMargin, for: .scrollContent)
        .scrollClipDisabled()
        .onChange(of: galleries.count) { _, newCount in
            guard newCount > 0 else { return }
            windowBase = 0
            scrollPositionID = newCount * middleBlock + min(max(pageIndex, 0), newCount - 1)
        }
        // Nearest-center handoff: `.viewAligned` settles on the nearest alignment, so the card
        // that crosses the container's midline is the card the scroll will land on. Flipping
        // `pageIndex` (→ `currentCardID` → the focused-card gradient) at the crossing hands the
        // gradient over while the card is still sliding in, instead of ~0.5s later when the
        // scroll reaches `.idle`. The `.idle` write below stays as the settle-time reconciliation.
        // The transform returns the LOGICAL index, so the window rebase (slots and offset shift
        // together by whole blocks, logical value unchanged) never fires this action.
        //
        // The action also re-anchors while the phase is `.idle`, which is the second of the two
        // bounded exceptions to "`scrollPositionID` is never written during scrolling" that
        // `bufferedCards` names. VoiceOver scrolls the carousel itself when focus moves to the next
        // card, and that scroll raises no phase, so SwiftUI — which only updates `scrollPositionID`
        // when a phase settles — leaves the anchor on the last gesture-settled card. Since
        // `scrollPosition(id:)` holds that card in place across the next content change, the offset
        // later snaps back to it, the focused card leaves the screen and VoiceOver drops focus to
        // the screen's first element (Phase 16 VO-1: in the instrumented build every reset followed
        // exactly this jump, about 1.17 s later, and nothing else did). Writing the anchor here
        // keeps it on the card the offset already shows: `.idle` means no drag, deceleration or
        // animation is in flight, and the value written is the card that is already centred, so
        // nothing scrolls and no gesture can be cancelled. The id written is the MIDDLE-block copy,
        // the only block the cards above expose, so a `previous` step from the Frontpage heading
        // returns to the last of the six rather than a neighbouring block's copy of it.
        .onScrollGeometryChange(for: Int.self) { geometry in
            let count = galleries.count
            guard count > 0, cardWidth > 0 else { return pageIndex }
            // `visibleRect.midX` is inset-convention-proof here: the `.scrollContent` margins are
            // symmetric, so the visible midpoint is identical whether or not they are included.
            let rawSlot = ((geometry.visibleRect.midX - cardWidth / 2) / cardPitch).rounded()
            let slot = min(max(Int(rawSlot), 0), count * windowBlocks - 1)
            return logicalIndex(of: windowBase + slot)
        } action: { _, newValue in
            guard !galleries.isEmpty, pageIndex != newValue else { return }
            pageIndex = newValue
            guard scrollPhase == .idle else { return }
            scrollPositionID = windowBase + galleries.count * middleBlock + newValue
        }
        .onScrollPhaseChange { _, newPhase in
            scrollPhase = newPhase
            guard newPhase == .idle, let settledID = scrollPositionID, !galleries.isEmpty else { return }
            let count = galleries.count
            let logical = logicalIndex(of: settledID)
            // Outward-only `.synchronize` parity: the reducer only observes `cardPageIndex`,
            // it never writes it back, so no inward re-seam exists by design.
            if pageIndex != logical {
                pageIndex = logical
            }
            // Window rebase: shift `windowBase` so the settled card sits in the middle block.
            // This is a pure data change — the settled id keeps existing, `scrollPosition(id:)`
            // holds that view's offset across the diff, and `scrollPositionID` is untouched, so
            // the rebase is invisible, resets no view identity, and can't cancel a gesture.
            let slot = min(max(settledID - windowBase, 0), count * windowBlocks - 1)
            let block = slot / count
            guard block != middleBlock else { return }
            windowBase += (block - middleBlock) * count
        }
    }

    // Shared by the layout and the nearest-center geometry math — they must never drift apart.
    private var cardWidth: CGFloat { carouselWidth * 0.8 }
    private var cardPitch: CGFloat { cardWidth + cardSpacing }
    private let cardSpacing: CGFloat = 20

    // Center the snapped card: bare `.viewAligned` aligns the card's leading edge to the
    // content edge, dumping all the peek on the trailing side, while SwiftUIPager centered
    // the focused card. Symmetric margins of the leftover width restore the centered peek.
    private var centeringMargin: CGFloat {
        (carouselWidth - cardWidth) / 2
    }

    private func card(for gallery: Gallery) -> some View {
        Button {
            navigateAction(gallery)
        } label: {
            GalleryCardCell(
                gallery: gallery,
                currentID: currentID,
                colors: colors,
                maximumHeight: maximumCardHeight,
                webImageSuccessAction: {
                    webImageSuccessAction(gallery.gid, $0)
                }
            )
            .tint(.primary)
            .multilineTextAlignment(.leading)
        }
        .frame(width: cardWidth)
        // Peek dimming, owner-tuned: SwiftUIPager parity was `interactive(opacity: 0.2)`, but at
        // this card size the peek slivers are thin, and 0.2 over the dark background rendered
        // them practically invisible. 0.6 keeps the neighbors clearly readable yet de-emphasized.
        .scrollTransition { content, phase in
            content.opacity(phase.isIdentity ? 1 : 0.6)
        }
    }
}

// MARK: CoverWallSection
struct CoverWallSection: View {
    @GalleryCoverMetrics(.standard) private var coverSize
    private let galleries: [Gallery]
    private let isLoading: Bool
    private let navigateAction: (Gallery) -> Void
    private let showAllAction: () -> Void
    private let reloadAction: () -> Void

    init(
        galleries: [Gallery], isLoading: Bool,
        navigateAction: @escaping (Gallery) -> Void,
        showAllAction: @escaping () -> Void,
        reloadAction: @escaping () -> Void
    ) {
        self.galleries = galleries
        self.isLoading = isLoading
        self.navigateAction = navigateAction
        self.showAllAction = showAllAction
        self.reloadAction = reloadAction
    }

    private var dataSource: [[Gallery]] {
        var galleries = galleries
        if galleries.isEmpty {
            galleries = Gallery.mockGalleries(count: 25)
        }
        // Pairs in data order, dropping an odd trailing gallery: each stack shows two covers.
        var remaining = galleries[...]
        var pairs: [[Gallery]] = []
        while let upper = remaining.popFirst(), let lower = remaining.popFirst() {
            pairs.append([upper, lower])
        }
        return pairs
    }

    var body: some View {
        SubSection(
            title: .frontpage,
            isLoading: isLoading,
            reloadAction: reloadAction,
            showAllAction: showAllAction
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 20) {
                    ForEach(dataSource, id: \.first) {
                        VerticalCoverStack(galleries: $0, navigateAction: navigateAction)
                    }
                    .withHorizontalSpacing(width: 0)
                }
            }
            .frame(height: coverSize.height * 2 + 30)
        }
    }
}

struct VerticalCoverStack: View {
    private let galleries: [Gallery]
    private let navigateAction: (Gallery) -> Void

    init(galleries: [Gallery], navigateAction: @escaping (Gallery) -> Void) {
        self.galleries = galleries
        self.navigateAction = navigateAction
    }

    /// The cover is the button's only content, so without a label VoiceOver and Voice Control got
    /// an unnamed button (eight of them on Home, the Phase 16 automated audit's "element has no
    /// description"); the gallery's title is what the cover stands for.
    private func imageContainer(gallery: Gallery) -> some View {
        Button {
            navigateAction(gallery)
        } label: {
            GalleryCover(url: gallery.coverURL, style: .standard)
        }
        .accessibilityLabel(gallery.title)
    }

    var body: some View {
        VStack(spacing: 20) {
            ForEach(galleries, content: imageContainer)
        }
    }
}

// MARK: ToplistsSection
struct ToplistsSection: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @Dependency(\.deviceClient) private var deviceClient

    private let galleries: [Int: [Gallery]]
    private let isLoading: Bool
    private let navigateAction: (Gallery) -> Void
    private let showAllAction: () -> Void
    private let reloadAction: () -> Void

    init(
        galleries: [Int: [Gallery]], isLoading: Bool,
        navigateAction: @escaping (Gallery) -> Void,
        showAllAction: @escaping () -> Void,
        reloadAction: @escaping () -> Void
    ) {
        self.galleries = galleries
        self.isLoading = isLoading
        self.navigateAction = navigateAction
        self.showAllAction = showAllAction
        self.reloadAction = reloadAction
    }

    private var dataSource: [Int: [Gallery]] {
        guard !galleries.isEmpty else {
            var dictionary = [Int: [Gallery]]()
            var gallery: Gallery = .preview
            gallery.title = "......"
            gallery.uploader = "......"
            let galleries = Array(repeating: gallery, count: 6)

            ToplistsType.allCases.forEach { type in
                dictionary[type.categoryIndex] = galleries
            }
            return dictionary
        }
        return galleries
    }
    private func galleries(type: ToplistsType, range: ClosedRange<Int>) -> [Gallery] {
        let galleries = dataSource[type.categoryIndex] ?? []
        guard galleries.count > range.upperBound else { return [] }
        return Array(galleries[range])
    }

    var body: some View {
        SubSection(
            title: .toplists,
            isLoading: isLoading,
            reloadAction: reloadAction,
            showAllAction: showAllAction
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top) {
                    ForEach(ToplistsType.allCases, content: verticalStacks)
                }
            }
        }
    }
    private func verticalStacks(type: ToplistsType) -> some View {
        VStack(alignment: .leading) {
            Text(type.value).font(.subheadline.bold())
            if deviceClient.deviceType() == .pad, horizontalSizeClass == .regular {
                regularWidthGrid(type: type)
            } else {
                VerticalToplistsStack(
                    galleries: galleries(type: type, range: 0...2), startRanking: 1,
                    navigateAction: navigateAction
                )
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 5)
    }

    private func regularWidthGrid(type: ToplistsType) -> some View {
        let sectionGalleries = dataSource[type.categoryIndex] ?? []
        let rowCount = min(3, sectionGalleries.count)

        return Grid(horizontalSpacing: 8, verticalSpacing: 10) {
            ForEach(0..<rowCount, id: \.self) { offset in
                GridRow {
                    if let leadingGallery = sectionGalleries.dropFirst(offset).first {
                        regularWidthCell(
                            gallery: leadingGallery,
                            ranking: offset + 1,
                            showsDivider: offset < rowCount - 1
                        )
                    }

                    let trailingIndex = offset + 3
                    if trailingIndex < sectionGalleries.count,
                       let trailingGallery = sectionGalleries.dropFirst(trailingIndex).first {
                        regularWidthCell(
                            gallery: trailingGallery,
                            ranking: offset + 4,
                            showsDivider: trailingIndex < sectionGalleries.count - 1
                        )
                    } else {
                        Color.clear.accessibilityHidden(true)
                    }
                }
            }
        }
        .containerRelativeFrame(.horizontal) { width, _ in width * 0.8 }
    }

    private func regularWidthCell(
        gallery: Gallery,
        ranking: Int,
        showsDivider: Bool
    ) -> some View {
        VStack(spacing: 10) {
            Button {
                navigateAction(gallery)
            } label: {
                GalleryRankingCell(gallery: gallery, ranking: ranking)
                    .tint(.primary)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            Divider().opacity(showsDivider ? 1 : 0)
        }
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

struct VerticalToplistsStack: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    private let galleries: [Gallery]
    private let startRanking: Int
    private let navigateAction: (Gallery) -> Void

    init(
        galleries: [Gallery],
        startRanking: Int,
        navigateAction: @escaping (Gallery) -> Void
    ) {
        self.galleries = galleries
        self.startRanking = startRanking
        self.navigateAction = navigateAction
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(galleries.enumerated(), id: \.offset) { offset, gallery in
                VStack(spacing: 10) {
                    Button {
                        navigateAction(gallery)
                    } label: {
                        GalleryRankingCell(gallery: gallery, ranking: startRanking + offset)
                            .tint(.primary).multilineTextAlignment(.leading)
                    }
                    Divider().opacity(offset == galleries.count - 1 ? 0 : 1)
                }
            }
        }
        .containerRelativeFrame(.horizontal) { width, _ in
            width * (horizontalSizeClass == .regular ? 0.4 : 0.7)
        }
    }
}

// MARK: MiscGridSection
struct MiscGridSection: View {
    private let navigateAction: (HomeMiscGridType) -> Void

    init(navigateAction: @escaping (HomeMiscGridType) -> Void) {
        self.navigateAction = navigateAction
    }

    var body: some View {
        SubSection(title: .other, showAll: false) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    let types = HomeMiscGridType.allCases
                    ForEach(types) { type in
                        Button {
                            navigateAction(type)
                        } label: {
                            MiscGridItem(title: type.title, symbol: type.symbol).tint(.primary)
                        }
                        .padding(.trailing, type == types.last ? 0 : 10)
                    }
                    .withHorizontalSpacing()
                }
            }
        }
    }
}

struct MiscGridItem: View {
    private let title: LocalizedStringResource
    private let subTitle: LocalizedStringResource?
    private let symbol: SFSymbol

    init(title: LocalizedStringResource, subTitle: LocalizedStringResource? = nil, symbol: SFSymbol) {
        self.title = title
        self.subTitle = subTitle
        self.symbol = symbol
    }

    // 50pt at default (.large); scales with Dynamic Type relative to the nearest text style (.largeTitle, 34pt).
    @ScaledMetric(relativeTo: .largeTitle) private var symbolSize: CGFloat = 50

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title).font(.title2.bold()).frame(minWidth: 100)
                if let subTitle = subTitle {
                    Text(subTitle).font(.subheadline).foregroundStyle(.secondary).lineLimit(2)
                }
            }
            Image(systemSymbol: symbol)
                .font(.system(size: symbolSize, weight: .light, design: .default))
                .foregroundStyle(.secondary)
                .imageScale(.large)
                .offset(x: 20, y: 20)
        }
        .padding(30)
        .glassEffect(.clear.tint(.init(.systemGray6)), in: .rect(cornerRadius: 15))
    }
}
