import SwiftUI
import Sharing
import AppModels
import AppComponents

public struct GenericList: View {
    @SharedReader(.setting) private var setting: Setting

    private let galleries: [Gallery]
    private let downloadBadges: [String: DownloadBadge]
    private let pageNumber: PageNumber?
    private let loadingState: LoadingState
    private let footerLoadingState: LoadingState
    private let notice: LocalizedStringResource?
    private let fetchAction: (() -> Void)?
    private let fetchMoreAction: (() -> Void)?
    private let navigateAction: ((Gallery) -> Void)?
    private let translateAction: ((String) -> (String, TagTranslation?))?

    public init(
        galleries: [Gallery], pageNumber: PageNumber?,
        loadingState: LoadingState, footerLoadingState: LoadingState,
        notice: LocalizedStringResource? = nil,
        fetchAction: (() -> Void)? = nil,
        fetchMoreAction: (() -> Void)? = nil,
        navigateAction: ((Gallery) -> Void)? = nil,
        translateAction: ((String) -> (String, TagTranslation?))? = nil,
        downloadBadges: [String: DownloadBadge] = [:]
    ) {
        self.galleries = galleries
        self.downloadBadges = downloadBadges
        self.pageNumber = pageNumber
        self.loadingState = loadingState
        self.footerLoadingState = footerLoadingState
        self.notice = notice
        self.fetchAction = fetchAction
        self.fetchMoreAction = fetchMoreAction
        self.navigateAction = navigateAction
        self.translateAction = translateAction
    }

    public var body: some View {
        ZStack {
            VStack(spacing: 0) {
                switch setting.listDisplayMode {
                case .detail:
                    DetailList(
                        galleries: galleries, pageNumber: pageNumber,
                        footerLoadingState: footerLoadingState, notice: notice,
                        fetchMoreAction: fetchMoreAction,
                        navigateAction: navigateAction, translateAction: translateAction,
                        downloadBadges: downloadBadges
                    )
                case .thumbnail:
                    WaterfallList(
                        galleries: galleries, pageNumber: pageNumber,
                        footerLoadingState: footerLoadingState, notice: notice,
                        fetchMoreAction: fetchMoreAction,
                        navigateAction: navigateAction, translateAction: translateAction,
                        downloadBadges: downloadBadges
                    )
                }
            }
            .opacity(loadingState == .idle ? 1 : 0).zIndex(2)

            LoadingView()
                .opacity(loadingState == .loading ? 1 : 0).zIndex(0)

            ErrorView(error: loadingState.failed ?? .unknown, action: fetchAction)
                .opacity([.idle, .loading].contains(loadingState) ? 0 : 1)
                .zIndex(1)
        }
        .animation(.default, value: loadingState)
        .animation(.default, value: galleries)
        .refreshable { fetchAction?() }
    }
}

// MARK: DetailList
private struct DetailList: View {
    private let galleries: [Gallery]
    private let downloadBadges: [String: DownloadBadge]
    private let pageNumber: PageNumber?
    private let footerLoadingState: LoadingState
    private let notice: LocalizedStringResource?
    private let fetchMoreAction: (() -> Void)?
    private let navigateAction: ((Gallery) -> Void)?
    private let translateAction: ((String) -> (String, TagTranslation?))?

    init(
        galleries: [Gallery], pageNumber: PageNumber?,
        footerLoadingState: LoadingState, notice: LocalizedStringResource? = nil,
        fetchMoreAction: (() -> Void)?,
        navigateAction: ((Gallery) -> Void)? = nil,
        translateAction: ((String) -> (String, TagTranslation?))? = nil,
        downloadBadges: [String: DownloadBadge] = [:]
    ) {
        self.galleries = galleries
        self.downloadBadges = downloadBadges
        self.pageNumber = pageNumber
        self.footerLoadingState = footerLoadingState
        self.notice = notice
        self.fetchMoreAction = fetchMoreAction
        self.navigateAction = navigateAction
        self.translateAction = translateAction
    }

    private func shouldShowFooter(gallery: Gallery) -> Bool {
        guard let pageNumber = pageNumber else { return false }

        let isLastGallery = gallery == galleries.last
        let isPageNumberValid = pageNumber.hasNextPage()
        let isLoadingStateIdle = footerLoadingState == .idle

        return isLastGallery && isPageNumberValid && !isLoadingStateIdle
    }

    var body: some View {
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
                .foregroundColor(.primary)
                .onAppear {
                    if gallery == galleries.last {
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

// MARK: WaterfallList
private struct WaterfallList: View {
    private let galleries: [Gallery]
    private let downloadBadges: [String: DownloadBadge]
    private let pageNumber: PageNumber?
    private let footerLoadingState: LoadingState
    private let notice: LocalizedStringResource?
    private let fetchMoreAction: (() -> Void)?
    private let navigateAction: ((Gallery) -> Void)?
    private let translateAction: ((String) -> (String, TagTranslation?))?

    // Guards for the scroll-driven auto-load below. The load's own append perturbs the scroll
    // geometry (contentSize grows, then the List shifts contentOffset to keep the visible footer
    // row anchored), so any geometry-keyed re-arm is re-triggered by the load itself — that fed
    // an endless fetch loop pinned at the bottom. Instead: fire at most once per galleries.count
    // (data, which layout can't perturb) and only during user-driven scroll phases (finger drag
    // or momentum — layout-driven offset jumps happen in the idle/animating phases).
    @State private var isUserScrolling = false
    @State private var lastAutoFetchCount: Int?

    // Distance from the bottom edge at which the next page is auto-loaded (points).
    private static let fetchMoreThreshold: CGFloat = 300

    init(
        galleries: [Gallery], pageNumber: PageNumber?,
        footerLoadingState: LoadingState, notice: LocalizedStringResource? = nil,
        fetchMoreAction: (() -> Void)?,
        navigateAction: ((Gallery) -> Void)? = nil,
        translateAction: ((String) -> (String, TagTranslation?))? = nil,
        downloadBadges: [String: DownloadBadge] = [:]
    ) {
        self.galleries = galleries
        self.downloadBadges = downloadBadges
        self.pageNumber = pageNumber
        self.footerLoadingState = footerLoadingState
        self.notice = notice
        self.fetchMoreAction = fetchMoreAction
        self.navigateAction = navigateAction
        self.translateAction = translateAction
    }

    var body: some View {
        List {
            if let notice {
                Section {
                    ListNoticeView(notice: notice)
                }
            }
            // The thumbnail grid renders through the app-owned MasonryLayout (DEP-04), one eager row
            // inside this List. `.animation(nil, value: galleries)` suppresses placement animation on
            // fetch-more append (D-31, RESEARCH Pattern 3).
            // The footer (spinner while loading, retry on failure) lives INSIDE the masonry's row,
            // not as a sibling row: during an append the List keeps visible rows anchored, so a
            // visible standalone footer row pinned the viewport to the bottom while the masonry
            // row above it grew (measured as a negative distance-to-bottom) — chaining auto-loads
            // page after page (D-36). As part of this single row, nothing below the grid gets
            // anchored; appended content extends below the viewport and the scroll offset stays put.
            VStack(spacing: 0) {
                MasonryLayout {
                    ForEach(galleries) { gallery in
                        Button {
                            navigateAction?(gallery)
                        } label: {
                            GalleryThumbnailCell(
                                gallery: gallery,
                                translateAction: translateAction,
                                downloadBadge: downloadBadges[gallery.gid]
                            )
                            .tint(.primary).multilineTextAlignment(.leading)
                        }
                        .buttonStyle(.borderless)
                    }
                }
                .animation(nil, value: galleries)
                if let pageNumber, pageNumber.hasNextPage() {
                    FetchMoreFooter(
                        loadingState: footerLoadingState,
                        retryAction: fetchMoreAction
                    )
                }
            }
        }
        .listStyle(.plain)
        // Auto-load the next page as the bottom edge nears, mirroring DetailList's paginate-on-
        // scroll behavior. Reading scroll geometry (not view identity) keeps the scroll position
        // stable across appends. The guards (see the @State declarations above) break the
        // load→geometry→load feedback loop: user-driven scroll phase + once per page.
        .onScrollPhaseChange { _, newPhase in
            isUserScrolling = newPhase == .tracking || newPhase == .interacting || newPhase == .decelerating
        }
        .onScrollGeometryChange(for: CGFloat.self) { geometry in
            geometry.contentSize.height - geometry.contentOffset.y - geometry.containerSize.height
        } action: { _, distanceToBottom in
            guard distanceToBottom < Self.fetchMoreThreshold,
                  isUserScrolling,
                  footerLoadingState == .idle,
                  lastAutoFetchCount != galleries.count
            else { return }
            lastAutoFetchCount = galleries.count
            fetchMoreAction?()
        }
    }
}
