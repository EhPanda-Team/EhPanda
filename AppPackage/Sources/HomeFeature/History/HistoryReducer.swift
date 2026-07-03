import Foundation
import AppModels
import Resources
import ComposableArchitecture
import AppTools
import HapticsClient
import DatabaseClient
import DownloadClient
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
        case fetchGalleriesDone([Gallery])
        case observeDownloads
        case observeDownloadsDone([DownloadedGallery])
    }

    @Dependency(\.databaseClient) private var databaseClient
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
                state.confirmationDialog = ConfirmationDialogState {
                    TextState("")
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
                return .merge(
                    .run(operation: { _ in await databaseClient.clearHistoryGalleries() }),
                    .run { send in
                        try await Task.sleep(for: .milliseconds(200))
                        await send(.fetchGalleries)
                    }
                )

            case .fetchGalleries:
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                return .run { send in
                    let historyGalleries = await databaseClient.fetchHistoryGalleries()
                    await send(.fetchGalleriesDone(historyGalleries))
                }

            case .fetchGalleriesDone(let galleries):
                state.loadingState = .idle
                if galleries.isEmpty {
                    state.loadingState = .failed(.notFound)
                } else {
                    state.galleries = galleries
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
