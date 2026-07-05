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
    }

    public enum Delegate: Equatable, Sendable {
        case pushDetail(String)
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
        case fetchGalleriesDone(Result<[Gallery], AppError>)
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
                // browser-like. The write is synchronous, so we can refetch straight away.
                state.$galleryHistory.withLock { $0.removeAll() }
                return .send(.fetchGalleries)

            case .fetchGalleries:
                guard state.loadingState != .loading else { return .none }
                let pairs = state.galleryHistory.map { (gid: $0.gid, token: $0.token) }
                guard !pairs.isEmpty else {
                    state.galleries = []
                    state.loadingState = .failed(.notFound)
                    return .none
                }
                state.loadingState = .loading
                return .run { send in
                    let response = await GalleriesMetadataRequest(gidList: pairs).response()
                    await send(.fetchGalleriesDone(response))
                }

            case .fetchGalleriesDone(let result):
                state.loadingState = .idle
                switch result {
                case .success(let galleries):
                    if galleries.isEmpty {
                        state.loadingState = .failed(.notFound)
                    } else {
                        state.galleries = galleries
                    }
                case .failure(let error):
                    state.loadingState = .failed(error)
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
