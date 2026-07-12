import SwiftUI
import AppModels
import Resources
import Kingfisher
import SFSafeSymbols
import AppTools
import AppComponents
import OSLogExt

private let logger = Logger(category: .init(describing: CardSlideSection.self))

// MARK: CardSlideSection
struct CardSlideSection: View, Equatable {
    @State private var scrollPositionID: Int?
    @State private var performingChanges = false
    @Binding private var pageIndex: Int

    private let galleries: [Gallery]
    private let currentID: String
    private let colors: [Color]
    private let navigateAction: (Gallery) -> Void
    private let webImageSuccessAction: (String, RetrieveImageResult) -> Void

    init(
        galleries: [Gallery], pageIndex: Binding<Int>, currentID: String,
        colors: [Color],
        navigateAction: @escaping (Gallery) -> Void,
        webImageSuccessAction: @escaping (String, RetrieveImageResult) -> Void
    ) {
        self.galleries = galleries
        _pageIndex = pageIndex
        self.currentID = currentID
        self.colors = colors
        self.navigateAction = navigateAction
        self.webImageSuccessAction = webImageSuccessAction
        // Seed the initial position to the MIDDLE copy's entry for the inbound page index
        // (`Page.withIndex` parity: `cardPageIndex` defaults to 1, so the carousel must not open
        // on the first card), giving the loop headroom on both sides from the first frame.
        let seedIndex = galleries.isEmpty ? nil : min(max(pageIndex.wrappedValue, 0), galleries.count - 1)
        _scrollPositionID = State(initialValue: seedIndex.map { galleries.count + $0 })
    }

    static func == (lhs: CardSlideSection, rhs: CardSlideSection) -> Bool {
        lhs.galleries == rhs.galleries
            && lhs.currentID == rhs.currentID
            && lhs.colors == rhs.colors
    }

    // Three concatenated copies of `galleries` with block-distinct ids replace `.loopPages()`:
    // the carousel rests in the middle copy, so wrap-around always has cards on both sides,
    // and a silent re-center restores that headroom whenever a scroll settles in an edge copy.
    private struct BufferedCard: Identifiable, Equatable {
        let id: Int
        let gallery: Gallery
    }

    private var bufferedCards: [BufferedCard] {
        let count = galleries.count
        guard count > 0 else { return [] }
        return (0..<count * 3).map { bufferIndex in
            BufferedCard(id: bufferIndex, gallery: galleries[bufferIndex % count])
        }
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: cardSpacing) {
                ForEach(bufferedCards) { item in
                    card(for: item.gallery)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollPosition(id: $scrollPositionID)
        .contentMargins(.horizontal, centeringMargin, for: .scrollContent)
        .scrollClipDisabled()
        .frame(height: Defaults.FrameSize.cardCellHeight)
        // Nearest-center handoff: `.viewAligned` settles on the nearest alignment, so the card
        // that crosses the container's midline is the card the scroll will land on. Flipping
        // `pageIndex` (→ `currentCardID` → the focused-card gradient) at the crossing hands the
        // gradient over while the card is still sliding in, instead of ~0.5s later when the
        // scroll reaches `.idle`. The `.idle` write below stays as the settle-time reconciliation.
        // The transform returns the LOGICAL index, so the tripled-buffer re-center (buffer id
        // jumps by ±count, logical value unchanged) never fires this action.
        .onScrollGeometryChange(for: Int.self) { geometry in
            let count = galleries.count
            guard count > 0 else { return 0 }
            // `visibleRect.midX` is inset-convention-proof here: the `.scrollContent` margins are
            // symmetric, so the visible midpoint is identical whether or not they are included.
            let rawIndex = ((geometry.visibleRect.midX - cardWidth / 2) / cardPitch).rounded()
            let bufferIndex = min(max(Int(rawIndex), 0), count * 3 - 1)
            return bufferIndex % count
        } action: { oldValue, newValue in
            guard !galleries.isEmpty, pageIndex != newValue else { return }
            // THROWAWAY (removed after go/no-go sign-off): crossing-time evidence — compare
            // timestamps with the `settled:` line to measure how early the handoff fires, and
            // the settled buffer id modulo count must equal the last crossing's logical index.
            logger.debug(
                "carousel crossing: \(oldValue, privacy: .public) -> \(newValue, privacy: .public)"
            )
            pageIndex = newValue
        }
        .onChange(of: scrollPositionID) { _, newValue in
            // THROWAWAY (removed after go/no-go sign-off): records when the scrollPosition
            // binding itself updates relative to the geometry crossing — the timing evidence
            // for whether the binding could have driven the handoff instead.
            logger.debug("carousel scrollPositionID: \(newValue ?? -1, privacy: .public)")
        }
        .onScrollPhaseChange { _, newPhase in
            guard newPhase == .idle, !performingChanges,
                  let settledID = scrollPositionID, !galleries.isEmpty
            else { return }
            let count = galleries.count
            let clampedID = min(max(settledID, 0), count * 3 - 1)
            let logicalIndex = clampedID % count
            // THROWAWAY (removed after go/no-go sign-off): settle-time self-validation for the
            // geometry math above (`settled logical` must match the last `crossing:` value).
            logger.debug(
                "carousel settled: buffer \(clampedID, privacy: .public), logical \(logicalIndex, privacy: .public)"
            )
            // Outward-only `.synchronize` parity: the reducer only observes `cardPageIndex`,
            // it never writes it back, so no inward re-seam exists by design.
            if pageIndex != logicalIndex {
                pageIndex = logicalIndex
            }
            let middleBlockID = count + logicalIndex
            guard clampedID != middleBlockID else { return }
            // Silent re-center onto the middle copy's equivalent card. The transaction
            // suppresses the animation so the swap is invisible at rest, and the flag keeps
            // the programmatic write from re-firing this mapping while it settles.
            performingChanges = true
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                scrollPositionID = middleBlockID
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                performingChanges = false
            }
        }
    }

    // Shared by the layout and the nearest-center geometry math — they must never drift apart.
    private var cardWidth: CGFloat { Defaults.FrameSize.cardCellSize.width }
    private var cardPitch: CGFloat { cardWidth + cardSpacing }
    private let cardSpacing: CGFloat = 20

    // Center the snapped card: bare `.viewAligned` aligns the card's leading edge to the
    // content edge, dumping all the peek on the trailing side, while SwiftUIPager centered
    // the focused card. Symmetric margins of the leftover width restore the centered peek.
    private var centeringMargin: CGFloat {
        (DeviceUtil.windowW - cardWidth) / 2
    }

    private func card(for gallery: Gallery) -> some View {
        Button {
            navigateAction(gallery)
        } label: {
            GalleryCardCell(
                gallery: gallery,
                currentID: currentID,
                colors: colors,
                webImageSuccessAction: {
                    webImageSuccessAction(gallery.gid, $0)
                }
            )
            .tint(.primary)
            .multilineTextAlignment(.leading)
        }
        .frame(width: cardWidth, height: Defaults.FrameSize.cardCellSize.height)
        .scrollTransition { content, phase in
            content.opacity(phase.isIdentity ? 1 : 0.2)
        }
    }
}

// MARK: CoverWallSection
struct CoverWallSection: View {
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
        if galleries.count % 2 != 0 { galleries = galleries.dropLast() }
        return stride(from: 0, to: galleries.count, by: 2).map { index in
            [galleries[index], galleries[index + 1]]
        }
    }

    var body: some View {
        SubSection(
            title: .frontpage,
            tint: .secondary, isLoading: isLoading,
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
            .frame(height: Defaults.ImageSize.rowH * 2 + 30)
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

    private func placeholder() -> some View {
        Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect))
    }
    private func imageContainer(gallery: Gallery) -> some View {
        Button {
            navigateAction(gallery)
        } label: {
            KFImage(gallery.coverURL)
                .placeholder(placeholder)
                .defaultModifier()
                .scaledToFill()
                .frame(width: Defaults.ImageSize.rowW, height: Defaults.ImageSize.rowH).cornerRadius(2)
        }
    }

    var body: some View {
        VStack(spacing: 20) {
            ForEach(galleries, content: imageContainer)
        }
    }
}

// MARK: ToplistsSection
struct ToplistsSection: View {
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
            tint: .secondary, isLoading: isLoading,
            reloadAction: reloadAction,
            showAllAction: showAllAction
        ) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(ToplistsType.allCases, content: verticalStacks)
                }
            }
        }
    }
    private func verticalStacks(type: ToplistsType) -> some View {
        VStack(alignment: .leading) {
            Text(type.value).font(.subheadline.bold())
            HStack {
                VerticalToplistsStack(
                    galleries: galleries(type: type, range: 0...2), startRanking: 1,
                    navigateAction: navigateAction
                )
                if DeviceUtil.isPad {
                    VerticalToplistsStack(
                        galleries: galleries(type: type, range: 3...5), startRanking: 4,
                        navigateAction: navigateAction
                    )
                }
            }
        }
        .padding(.horizontal, 20).padding(.vertical, 5)
    }
}

struct VerticalToplistsStack: View {
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
            ForEach(0..<galleries.count, id: \.self) { index in
                VStack(spacing: 10) {
                    Button {
                        navigateAction(galleries[index])
                    } label: {
                        GalleryRankingCell(gallery: galleries[index], ranking: startRanking + index)
                            .tint(.primary).multilineTextAlignment(.leading)
                    }
                    Divider().opacity(index == galleries.count - 1 ? 0 : 1)
                }
            }
        }
        .frame(width: Defaults.FrameSize.rankingCellWidth)
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

    var body: some View {
        HStack {
            VStack(alignment: .leading) {
                Text(title).font(.title2.bold()).lineLimit(1).frame(minWidth: 100)
                if let subTitle = subTitle {
                    Text(subTitle).font(.subheadline).foregroundColor(.secondary).lineLimit(2)
                }
            }
            Image(systemSymbol: symbol).font(.system(size: 50, weight: .light, design: .default))
                .foregroundColor(.secondary).imageScale(.large).offset(x: 20, y: 20)
        }
        .padding(30).cornerRadius(15).background(Color(.systemGray6).cornerRadius(15))
    }
}
