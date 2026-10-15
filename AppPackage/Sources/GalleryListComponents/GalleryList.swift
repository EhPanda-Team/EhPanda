import AppComponents
public import AppModels
import CasePathsCore
public import SwiftUI

public struct GalleryList: View {
    @AccessibilityFocusState private var localFocusedGalleryID: String?
    @State private var scrollPositionID: String?
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

    public init(
        displayMode: GalleryListDisplayMode,
        galleries: [Gallery], pageNumber: PageNumber?,
        loadingState: LoadingState, footerLoadingState: LoadingState,
        notice: LocalizedStringResource? = nil,
        fetchAction: (() -> Void)? = nil,
        fetchMoreAction: (() -> Void)? = nil,
        navigateAction: ((Gallery) -> Void)? = nil,
        translateAction: ((String) -> TagTranslationLookup)? = nil,
        downloadBadges: [String: DownloadBadge] = [:],
        galleryFocus: AccessibilityFocusState<String?>.Binding? = nil
    ) {
        self.galleries = galleries
        self.downloadBadges = downloadBadges
        self.pageNumber = pageNumber
        self.loadingState = loadingState
        self.footerLoadingState = footerLoadingState
        self.displayMode = displayMode
        self.notice = notice
        self.fetchAction = fetchAction
        self.fetchMoreAction = fetchMoreAction
        self.navigateAction = navigateAction
        self.translateAction = translateAction
        self.galleryFocus = galleryFocus
    }

    public var body: some View {
        let focusedGalleryID = galleryFocus ?? $localFocusedGalleryID
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
                    scrollPositionID: $scrollPositionID
                )
            case .grid:
                GridList(
                    galleries: galleries,
                    pageNumber: pageNumber,
                    footerLoadingState: footerLoadingState,
                    notice: notice,
                    fetchMoreAction: fetchMoreAction,
                    navigateAction: navigateAction,
                    translateAction: translateAction,
                    downloadBadges: downloadBadges,
                    galleryFocus: focusedGalleryID,
                    scrollPositionID: $scrollPositionID
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
        .onChange(of: galleries.map(\.id), initial: true) { _, ids in
            guard let current = scrollPositionID, ids.contains(current) else {
                scrollPositionID = ids.first
                return
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
                    .accessibilityFocused(galleryFocus, equals: gallery.id)
                    // Fetch-more fires when the trailing row actually becomes visible in the scroll
                    // container. Reducer loading guards make repeated visibility callbacks harmless.
                    .onScrollVisibilityChange { isVisible in
                        guard isVisible, gallery == galleries.last else { return }
                        fetchMoreAction?()
                    }
                    if shouldShowFooter(gallery: gallery) {
                        FetchMoreFooter(loadingState: footerLoadingState, retryAction: fetchMoreAction)
                    }
                }
            }
            .scrollTargetLayout()
            // The first target is the settled anchor for row mode. Keeping that anchor in the
            // parent lets a mode change restore the nearest surviving gallery without coupling the
            // two renderers to each other's layout assumptions.
            .onScrollTargetVisibilityChange(idType: String.self) { visibleIDs in
                guard let firstVisibleID = visibleIDs.first else { return }
                scrollPositionID = firstVisibleID
            }
            .onChange(of: scrollPositionID) { _, id in
                guard let id else { return }
                proxy.scrollTo(id, anchor: .center)
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

    var body: some View {
        ScrollView {
            if let notice {
                ListNoticeView(notice: notice)
                    .padding(.horizontal)
            }
            LazyVGrid(columns: [GridItem(.adaptive(minimum: minCellWidth), spacing: 12)], spacing: 16) {
                ForEach(galleries) { gallery in
                    Button {
                        navigateAction?(gallery)
                    } label: {
                        GalleryThumbnailCell(
                            gallery: gallery,
                            translateAction: translateAction,
                            downloadBadge: downloadBadges[gallery.gid]
                        )
                        .tint(.primary)
                        .multilineTextAlignment(.leading)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityFocused(galleryFocus, equals: gallery.id)
                    .onScrollVisibilityChange { isVisible in
                        guard isVisible, gallery == galleries.last else { return }
                        fetchMoreAction?()
                    }
                }
                if let pageNumber, pageNumber.hasNextPage() {
                    FetchMoreFooter(loadingState: footerLoadingState, retryAction: fetchMoreAction)
                        .gridCellColumns(1)
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal)
            .scrollEdgeEffectStyle(.soft, for: .top)
        }
        .scrollPosition(id: $scrollPositionID)
    }
}
