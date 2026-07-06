import Foundation
import AppModels
import Sharing
import Resources
import ComposableArchitecture
import AppTools
import HapticsClient
import DownloadClient
import NetworkingFeature
import AppComponents

@Reducer
public struct HistoryReducer: Sendable {
    private enum CancelID {
        case observeDownloads
        case fetch
    }

    // The gdata endpoint takes 25 gids/call; a page is two chunks, so a History visit costs at most a
    // couple of polite requests instead of refetching every (up to 1,000) entry at once.
    static let pageSize = 50

    public enum Delegate: Equatable, Sendable {
        case pushDetail(Gallery)
    }

    public enum Dialog: Equatable, Sendable {
        case confirmClearHistory
    }

    @ObservableState
    public struct State: Equatable {
        @Presents public var confirmationDialog: ConfirmationDialogState<Dialog>?
        public var keyword = ""
        public var downloadBadges = [String: DownloadBadge]()

        // The persisted browsing history (identity + recency + resume page, most-recent-first).
        // No gallery snapshot is stored, so `galleries` is the display metadata refetched on demand.
        @Shared(.galleryHistory) public var galleryHistory: [GalleryHistoryEntry]

        var filteredGalleries: [Gallery] {
            guard !keyword.isEmpty else { return galleries }
            return galleries.filter({ $0.title.caseInsensitiveContains(keyword) })
        }
        public var galleries = [Gallery]()
        public var loadingState: LoadingState = .idle
        // Paging over the local history: `fetchedCount` is how many most-recent entries have had their
        // display metadata fetched so far; `footerLoadingState` drives the "load more" spinner.
        public var footerLoadingState: LoadingState = .idle
        public var fetchedCount = 0

        // More history remains to page in beyond what's already been fetched.
        var hasMoreHistory: Bool { fetchedCount < galleryHistory.count }

        public init() {}
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case delegate(Delegate)
        case confirmationDialog(PresentationAction<Dialog>)
        case clearHistoryButtonTapped
        case clearHistoryGalleries

        case fetchGalleries
        case fetchGalleriesDone(Result<[Gallery], AppError>, endIndex: Int)
        case fetchMoreGalleries
        case fetchMoreGalleriesDone(Result<[Gallery], AppError>, endIndex: Int)
        case observeDownloads
        case observeDownloadsDone([DownloadedGallery])
    }

    @Dependency(\.downloadClient) private var downloadClient
    @Dependency(\.hapticsClient) private var hapticsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .send(.observeDownloads)

            case .delegate:
                return .none

            case .clearHistoryButtonTapped:
                state.confirmationDialog = ConfirmationDialogState(titleVisibility: .hidden) {
                    TextState(localized: .RLocalizable.clear)
                } actions: {
                    ButtonState(role: .destructive, action: .confirmClearHistory) {
                        TextState(localized: .RLocalizable.clear)
                    }
                    ButtonState(role: .cancel) {
                        TextState(localized: .RLocalizable.cancel)
                    }
                } message: {
                    TextState(localized: .RLocalizable.clearDescription)
                }
                return .none

            case .confirmationDialog(.presented(.confirmClearHistory)):
                return .send(.clearHistoryGalleries)

            case .confirmationDialog:
                return .none

            case .clearHistoryGalleries:
                // Clearing also drops resume positions (they live on the same entries) — deliberate,
                // browser-like. Cancel any in-flight fetch first so its late `.success` can't
                // repopulate the list we just emptied, then drop straight to the empty state.
                state.$galleryHistory.withLock { $0.removeAll() }
                state.galleries = []
                state.fetchedCount = 0
                state.footerLoadingState = .idle
                state.loadingState = .failed(.notFound)
                return .cancel(id: CancelID.fetch)

            case .fetchGalleries:
                guard state.loadingState != .loading else { return .none }
                state.galleries = []
                state.fetchedCount = 0
                state.footerLoadingState = .idle
                let end = min(Self.pageSize, state.galleryHistory.count)
                guard end > 0 else {
                    state.loadingState = .failed(.notFound)
                    return .none
                }
                let pairs = state.galleryHistory[0..<end].map { (gid: $0.gid, token: $0.token) }
                state.loadingState = .loading
                return .run { send in
                    let response = await GalleriesMetadataRequest(gidList: pairs).response()
                    await send(.fetchGalleriesDone(response, endIndex: end))
                }
                .cancellable(id: CancelID.fetch, cancelInFlight: true)

            case let .fetchGalleriesDone(result, endIndex):
                state.loadingState = .idle
                switch result {
                case .success(let galleries):
                    state.fetchedCount = endIndex
                    state.galleries = galleries
                    // Whole first page unresolved but more history remains: page on so the list isn't
                    // stuck empty with no cell to trigger the footer.
                    if galleries.isEmpty {
                        if state.hasMoreHistory {
                            return .send(.fetchMoreGalleries)
                        }
                        state.loadingState = .failed(.notFound)
                    }
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .fetchMoreGalleries:
                guard state.loadingState == .idle,
                      state.footerLoadingState != .loading,
                      state.hasMoreHistory
                else { return .none }
                let start = state.fetchedCount
                let end = min(start + Self.pageSize, state.galleryHistory.count)
                let pairs = state.galleryHistory[start..<end].map { (gid: $0.gid, token: $0.token) }
                state.footerLoadingState = .loading
                return .run { send in
                    let response = await GalleriesMetadataRequest(gidList: pairs).response()
                    await send(.fetchMoreGalleriesDone(response, endIndex: end))
                }
                .cancellable(id: CancelID.fetch, cancelInFlight: true)

            case let .fetchMoreGalleriesDone(result, endIndex):
                state.footerLoadingState = .idle
                switch result {
                case .success(let galleries):
                    state.fetchedCount = endIndex
                    state.galleries.append(contentsOf: galleries)
                    // This page was entirely unresolved; continue so paging doesn't stall mid-list.
                    if galleries.isEmpty && state.hasMoreHistory {
                        return .send(.fetchMoreGalleries)
                    }
                case .failure(let error):
                    state.footerLoadingState = .failed(error)
                }
                return .none

            case .observeDownloads:
                return .run { send in
                    for await downloads in downloadClient.observeDownloads() {
                        await send(.observeDownloadsDone(downloads))
                    }
                }
                .cancellable(id: CancelID.observeDownloads, cancelInFlight: true)

            case .observeDownloadsDone(let downloads):
                state.downloadBadges = Dictionary(
                    uniqueKeysWithValues: downloads.map { ($0.gid, $0.badge) }
                )
                return .none
            }
        }
        .ifLet(\.$confirmationDialog, action: \.confirmationDialog)
    }
}
