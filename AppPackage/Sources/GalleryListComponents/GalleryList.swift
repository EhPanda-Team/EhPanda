import AppComponents
public import AppModels
import CasePathsCore
public import SwiftUI

public struct GalleryList: View {
    @AccessibilityFocusState private var localFocusedGalleryID: String?
    @State private var localScrollPositionID: String?
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
        self.translateAction = translateAction
        self.galleryFocus = galleryFocus
        externalScrollPositionID = scrollPositionID
    }

    public var body: some View {
        let focusedGalleryID = galleryFocus ?? $localFocusedGalleryID
        let scrollPosition = externalScrollPositionID ?? $localScrollPositionID
        VStack(spacing: 0) {
            switch displayMode {
            case .row:
                DetailList(
                    galleries: galleries,
                    pageNumber: pageNumber,
                    footerLoadingState: footerLoadingState,
                    notice: notice,
                    fetchMoreAction: fetchMoreAction,
                    navigateAction: navigateAction,
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
                    fetchMoreAction: fetchMoreAction,
                    navigateAction: navigateAction,
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
        .overlay {
            ErrorView(error: loadingState.failed ?? .unknown, action: fetchAction)
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
}
// MARK: DetailList
private struct DetailList: View {
    @Binding private var scrollPositionID: String?
    @State private var restorationID: String?
    @State private var visibleIDs = Set<String>()
    private let galleryFocus: AccessibilityFocusState<String?>.Binding
    private let galleries: [Gallery]
    private let downloadBadges: [String: DownloadBadge]
    private let pageNumber: PageNumber?
    private let footerLoadingState: LoadingState
    private let notice: LocalizedStringResource?
    private let fetchMoreAction: (() -> Void)?
    private let navigateAction: ((Gallery) -> Void)?
    private let translateAction: ((String) -> TagTranslationLookup)?

    init(
        galleries: [Gallery], pageNumber: PageNumber?,
        footerLoadingState: LoadingState, notice: LocalizedStringResource? = nil,
        fetchMoreAction: (() -> Void)?,
        navigateAction: ((Gallery) -> Void)? = nil,
        translateAction: ((String) -> TagTranslationLookup)? = nil,
        downloadBadges: [String: DownloadBadge] = [:],
        galleryFocus: AccessibilityFocusState<String?>.Binding,
        scrollPositionID: Binding<String?>
    ) {
        _scrollPositionID = scrollPositionID
        _restorationID = State(initialValue: scrollPositionID.wrappedValue)
        self.galleries = galleries
        self.downloadBadges = downloadBadges
        self.pageNumber = pageNumber
        self.footerLoadingState = footerLoadingState
        self.notice = notice
        self.fetchMoreAction = fetchMoreAction
        self.navigateAction = navigateAction
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
        ScrollViewReader { proxy in
            List {
                notice.map(ListNoticeView.init)

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
                    .accessibilityIdentifier("gallery-list-item-\(gallery.id)")
                    .accessibilityFocused(galleryFocus, equals: gallery.id)
                    // Fetch-more fires when the trailing row actually becomes visible in the scroll
                    // container. Reducer loading guards make repeated visibility callbacks harmless.
                    .onScrollVisibilityChange(threshold: 0.1) { isVisible in
                        if isVisible {
                            visibleIDs.insert(gallery.id)
                        } else {
                            visibleIDs.remove(gallery.id)
                        }
                        if restorationID == nil, !visibleIDs.isEmpty {
                            scrollPositionID = galleries.first(where: { visibleIDs.contains($0.id) })?.id
                        }
                        if isVisible, gallery == galleries.last {
                            fetchMoreAction?()
                        }
                    }
                    if shouldShowFooter(gallery: gallery) {
                        FetchMoreFooter(loadingState: footerLoadingState, retryAction: fetchMoreAction)
                    }
                }
            }
            .onChange(of: galleries.isEmpty, initial: true) { _, isEmpty in
                guard !isEmpty, let id = restorationID else { return }
                // Let the native list reveal the complete row inside its navigation insets.
                proxy.scrollTo(id)
                restorationID = nil
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
    private let fetchMoreAction: (() -> Void)?
    private let navigateAction: ((Gallery) -> Void)?
    private let translateAction: ((String) -> TagTranslationLookup)?

    init(
        showsRating: Bool,
        galleries: [Gallery], pageNumber: PageNumber?,
        footerLoadingState: LoadingState, notice: LocalizedStringResource? = nil,
        fetchMoreAction: (() -> Void)?,
        navigateAction: ((Gallery) -> Void)? = nil,
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
        self.fetchMoreAction = fetchMoreAction
        self.navigateAction = navigateAction
        self.translateAction = translateAction
        self.galleryFocus = galleryFocus
    }

    var body: some View {
        ScrollView {
            if let notice {
                ListNoticeView(notice: notice)
                    .padding(.horizontal)
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
