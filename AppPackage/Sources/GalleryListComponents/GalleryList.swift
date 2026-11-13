import AppComponents
public import AppModels
import CasePathsCore
import Resources
public import SwiftUI

public struct GalleryList: View {
    @AccessibilityFocusState private var localFocusedGalleryID: String?
    @State private var localScrollPositionID: String?
    /// The notice's bottom edge in the list's frame, measured only while the error view shows.
    @State private var noticeBottom: CGFloat = 0
    private let externalScrollPositionID: Binding<String?>?
    private let galleryFocus: AccessibilityFocusState<String?>.Binding?

    private let galleries: [Gallery]
    private let downloadBadges: [String: DownloadBadge]
    private let pageNumber: PageNumber?
    private let loadingState: LoadingState
    private let footerLoadingState: LoadingState
    private let notice: LocalizedStringResource?
    private let fetchAction: (() -> Void)?
    private let fetchMoreAction: (() -> Void)?
    private let navigateAction: ((Gallery) -> Void)?
    private let readAction: ((Gallery) -> Void)?
    private let translateAction: ((String) -> TagTranslationLookup)?
    private let displayMode: GalleryListDisplayMode
    private let showsGridRating: Bool

    public init(
        displayMode: GalleryListDisplayMode,
        showsGridRating: Bool = true,
        galleries: [Gallery], pageNumber: PageNumber?,
        loadingState: LoadingState, footerLoadingState: LoadingState,
        notice: LocalizedStringResource? = nil,
        fetchAction: (() -> Void)? = nil,
        fetchMoreAction: (() -> Void)? = nil,
        navigateAction: ((Gallery) -> Void)? = nil,
        readAction: ((Gallery) -> Void)? = nil,
        translateAction: ((String) -> TagTranslationLookup)? = nil,
        downloadBadges: [String: DownloadBadge] = [:],
        galleryFocus: AccessibilityFocusState<String?>.Binding? = nil,
        scrollPositionID: Binding<String?>? = nil
    ) {
        self.galleries = galleries
        self.downloadBadges = downloadBadges
        self.pageNumber = pageNumber
        self.loadingState = loadingState
        self.footerLoadingState = footerLoadingState
        self.displayMode = displayMode
        self.showsGridRating = showsGridRating
        self.notice = notice
        self.fetchAction = fetchAction
        self.fetchMoreAction = fetchMoreAction
        self.navigateAction = navigateAction
        self.readAction = readAction
        self.translateAction = translateAction
        self.galleryFocus = galleryFocus
        externalScrollPositionID = scrollPositionID
    }

    public var body: some View {
        let focusedGalleryID = galleryFocus ?? $localFocusedGalleryID
        let scrollPosition = externalScrollPositionID ?? $localScrollPositionID
        let measuredNoticeBottom = notice != nil && loadingState.is(\.failed) ? $noticeBottom : nil
        VStack(spacing: 0) {
            switch displayMode {
            case .row:
                DetailList(
                    galleries: galleries,
                    pageNumber: pageNumber,
                    footerLoadingState: footerLoadingState,
                    notice: notice,
                    noticeBottom: measuredNoticeBottom,
                    fetchMoreAction: fetchMoreAction,
                    navigateAction: navigateAction,
                    readAction: readAction,
                    translateAction: translateAction,
                    downloadBadges: downloadBadges,
                    galleryFocus: focusedGalleryID,
                    scrollPositionID: scrollPosition
                )
            case .grid:
                GridList(
                    showsRating: showsGridRating,
                    galleries: galleries,
                    pageNumber: pageNumber,
                    footerLoadingState: footerLoadingState,
                    notice: notice,
                    noticeBottom: measuredNoticeBottom,
                    fetchMoreAction: fetchMoreAction,
                    navigateAction: navigateAction,
                    readAction: readAction,
                    translateAction: translateAction,
                    downloadBadges: downloadBadges,
                    galleryFocus: focusedGalleryID,
                    scrollPositionID: scrollPosition
                )
            }
        }
        .overlay {
            LoadingView()
                .animation(.default) {
                    $0.visible(loadingState == .loading)
                }
        }
        .coordinateSpace(.galleryList)
        .overlay {
            errorView
                .animation(.default) {
                    $0.visible(loadingState.is(\.failed))
                }
        }
        .refreshable { fetchAction?() }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .onChange(of: galleries.map(\.id), initial: true) { previousIDs, ids in
            scrollPosition.wrappedValue = GalleryScrollAnchor.retaining(
                scrollPosition.wrappedValue, previousIDs: previousIDs, currentIDs: ids
            )
        }
    }

    /// The error view, centred in the list as before. A list with a notice keeps the notice clear: at the largest
    /// text sizes the centred view covered History's notice (`history-empty`, iPhone accessibility5), so there it
    /// is centred below the notice instead, and scrolls when it is taller than that space.
    @ViewBuilder private var errorView: some View {
        let error = ErrorView(error: loadingState.failed ?? .unknown, action: fetchAction)
        if notice == nil {
            error
        } else {
            NoticeClearingLayout(noticeBottom: loadingState.is(\.failed) ? noticeBottom : 0) {
                ViewThatFits(in: .vertical) {
                    error
                    ScrollView { error }
                }
            }
        }
    }
}

extension CoordinateSpaceProtocol where Self == NamedCoordinateSpace {
    fileprivate static var galleryList: NamedCoordinateSpace { .named("GalleryList") }
}

/// Places its one view over the whole list, as an overlay does, unless the view's content, centred there, would
/// reach above `noticeBottom`; then it gets only the space below the notice.
private struct NoticeClearingLayout: Layout {
    let noticeBottom: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard let view = subviews.first else { return }
        let contentHeight = view.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
        let clearance = min(max(noticeBottom, 0), bounds.height)
        guard (bounds.height - contentHeight) / 2 < clearance else {
            view.place(at: bounds.origin, proposal: ProposedViewSize(bounds.size))
            return
        }
        view.place(
            at: CGPoint(x: bounds.minX, y: bounds.minY + clearance),
            proposal: ProposedViewSize(width: bounds.width, height: bounds.height - clearance)
        )
    }
}

/// Reports the notice's bottom edge in the list's frame to `bottom`, or nothing while `bottom` is `nil`, so a
/// scrolling list does not update its parent on every frame.
private struct NoticeBottomReporter: ViewModifier {
    let bottom: Binding<CGFloat>?

    func body(content: Content) -> some View {
        content.onGeometryChange(for: CGFloat?.self) { geometry in
            bottom == nil ? nil : geometry.frame(in: .galleryList).maxY
        } action: { value in
            if let value {
                bottom?.wrappedValue = value
            }
        }
    }
}
// MARK: DetailList
private struct DetailList: View {
    @Binding private var scrollPositionID: String?
    private let galleryFocus: AccessibilityFocusState<String?>.Binding
    private let galleries: [Gallery]
    private let downloadBadges: [String: DownloadBadge]
    private let pageNumber: PageNumber?
    private let footerLoadingState: LoadingState
    private let notice: LocalizedStringResource?
    private let noticeBottom: Binding<CGFloat>?
    private let fetchMoreAction: (() -> Void)?
    private let navigateAction: ((Gallery) -> Void)?
    private let readAction: ((Gallery) -> Void)?
    private let translateAction: ((String) -> TagTranslationLookup)?

    init(
        galleries: [Gallery], pageNumber: PageNumber?,
        footerLoadingState: LoadingState, notice: LocalizedStringResource? = nil,
        noticeBottom: Binding<CGFloat>? = nil,
        fetchMoreAction: (() -> Void)?,
        navigateAction: ((Gallery) -> Void)? = nil,
        readAction: ((Gallery) -> Void)? = nil,
        translateAction: ((String) -> TagTranslationLookup)? = nil,
        downloadBadges: [String: DownloadBadge] = [:],
        galleryFocus: AccessibilityFocusState<String?>.Binding,
        scrollPositionID: Binding<String?>
    ) {
        _scrollPositionID = scrollPositionID
        self.galleries = galleries
        self.downloadBadges = downloadBadges
        self.pageNumber = pageNumber
        self.footerLoadingState = footerLoadingState
        self.notice = notice
        self.noticeBottom = noticeBottom
        self.fetchMoreAction = fetchMoreAction
        self.navigateAction = navigateAction
        self.readAction = readAction
        self.translateAction = translateAction
        self.galleryFocus = galleryFocus
    }

    private func shouldShowFooter(gallery: Gallery) -> Bool {
        guard let pageNumber = pageNumber else { return false }

        let isLastGallery = gallery == galleries.last
        let isPageNumberValid = pageNumber.hasNextPage()
        let isLoadingStateIdle = footerLoadingState == .idle

        return isLastGallery && isPageNumberValid && !isLoadingStateIdle
    }

    var body: some View {
        GalleryAnchoredList(anchorID: $scrollPositionID, ids: galleries.map(\.id)) {
            if let notice {
                ListNoticeView(notice: notice)
                    .modifier(NoticeBottomReporter(bottom: noticeBottom))
            }

            ForEach(galleries) { gallery in
                Button {
                    navigateAction?(gallery)
                } label: {
                    GalleryDetailCell(
                        gallery: gallery,
                        translateAction: translateAction,
                        downloadBadge: downloadBadges[gallery.gid]
                    )
                }
                .id(gallery.id)
                .foregroundStyle(.primary)
                .modifier(GalleryReadInteraction(
                    detailAction: { navigateAction?(gallery) },
                    readAction: readAction.map { action in { action(gallery) } }
                ))
                .contextMenu {
                    if let readAction {
                        Button(.RLocalizable.read) { readAction(gallery) }
                    }
                }
                .accessibilityIdentifier("gallery-list-item-\(gallery.id)")
                .accessibilityFocused(galleryFocus, equals: gallery.id)
                .galleryRowAnchor(gallery.id)
                // Fetch-more fires when the trailing row actually becomes visible in the scroll
                // container. Reducer loading guards make repeated visibility callbacks harmless.
                .onScrollVisibilityChange(threshold: 0.1) { isVisible in
                    if isVisible, gallery == galleries.last {
                        fetchMoreAction?()
                    }
                }
                if shouldShowFooter(gallery: gallery) {
                    FetchMoreFooter(loadingState: footerLoadingState, retryAction: fetchMoreAction)
                }
            }
        }
    }
}
// MARK: GridList
private struct GridList: View {
    @Binding private var scrollPositionID: String?
    @ScaledMetric(relativeTo: .callout) private var minCellWidth: CGFloat = 180
    private let galleryFocus: AccessibilityFocusState<String?>.Binding

    private let galleries: [Gallery]
    private let showsRating: Bool
    private let downloadBadges: [String: DownloadBadge]
    private let pageNumber: PageNumber?
    private let footerLoadingState: LoadingState
    private let notice: LocalizedStringResource?
    private let noticeBottom: Binding<CGFloat>?
    private let fetchMoreAction: (() -> Void)?
    private let navigateAction: ((Gallery) -> Void)?
    private let readAction: ((Gallery) -> Void)?
    private let translateAction: ((String) -> TagTranslationLookup)?

    init(
        showsRating: Bool,
        galleries: [Gallery], pageNumber: PageNumber?,
        footerLoadingState: LoadingState, notice: LocalizedStringResource? = nil,
        noticeBottom: Binding<CGFloat>? = nil,
        fetchMoreAction: (() -> Void)?,
        navigateAction: ((Gallery) -> Void)? = nil,
        readAction: ((Gallery) -> Void)? = nil,
        translateAction: ((String) -> TagTranslationLookup)? = nil,
        downloadBadges: [String: DownloadBadge] = [:],
        galleryFocus: AccessibilityFocusState<String?>.Binding,
        scrollPositionID: Binding<String?>
    ) {
        _scrollPositionID = scrollPositionID
        self.galleries = galleries
        self.showsRating = showsRating
        self.downloadBadges = downloadBadges
        self.pageNumber = pageNumber
        self.footerLoadingState = footerLoadingState
        self.notice = notice
        self.noticeBottom = noticeBottom
        self.fetchMoreAction = fetchMoreAction
        self.navigateAction = navigateAction
        self.readAction = readAction
        self.translateAction = translateAction
        self.galleryFocus = galleryFocus
    }

    var body: some View {
        ScrollView {
            if let notice {
                ListNoticeView(notice: notice)
                    .padding(.horizontal)
                    .modifier(NoticeBottomReporter(bottom: noticeBottom))
            }
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: minCellWidth), spacing: 12, alignment: .top)], spacing: 16
            ) {
                ForEach(galleries) { gallery in
                    Button {
                        navigateAction?(gallery)
                    } label: {
                        GalleryThumbnailCell(
                            gallery: gallery,
                            translateAction: translateAction,
                            downloadBadge: downloadBadges[gallery.gid],
                            showsRating: showsRating
                        )
                        .tint(.primary)
                        .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.borderless)
                    .modifier(GalleryReadInteraction(
                        detailAction: { navigateAction?(gallery) },
                        readAction: readAction.map { action in { action(gallery) } }
                    ))
                    .accessibilityIdentifier("gallery-list-item-\(gallery.id)")
                    .accessibilityFocused(galleryFocus, equals: gallery.id)
                    .onScrollVisibilityChange(threshold: 0.1) { isVisible in
                        guard isVisible, gallery == galleries.last else { return }
                        fetchMoreAction?()
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal)
            if let pageNumber, pageNumber.hasNextPage() {
                FetchMoreFooter(loadingState: footerLoadingState, retryAction: fetchMoreAction)
            }
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .scrollPosition(id: $scrollPositionID, anchor: .top)
    }
}
