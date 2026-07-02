import Foundation
import AppModels
import ComposableArchitecture
import HapticsClient
import NetworkingFeature
import ClipboardClient
import FileClient
import AppComponents

@Reducer
public struct TorrentsReducer: Sendable {
    @Reducer
    public enum Destination {
        @ReducerCaseIgnored
        case share(URL)
    }

    private enum CancelID {
        case fetchTorrent, fetchGalleryTorrents
    }

    @ObservableState
    public struct State: Equatable {
        @Presents public var toast: AppAlertState<Never>?
        @Presents public var destination: Destination.State?
        public var torrents = [GalleryTorrent]()
        public var loadingState: LoadingState = .idle
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case toast(PresentationAction<Never>)
        case destination(PresentationAction<Destination.Action>)
        case presentShare(URL)

        case copyText(String)
        case presentTorrentActivity(String, Data)

        case fetchTorrent(String, URL)
        case fetchTorrentDone(String, Result<Data, AppError>)
        case fetchGalleryTorrents(String, String)
        case fetchGalleryTorrentsDone(Result<[GalleryTorrent], AppError>)
    }

    @Dependency(\.clipboardClient) private var clipboardClient
    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.fileClient) private var fileClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .toast:
                return .none

            case .destination:
                return .none

            case .presentShare(let url):
                state.destination = .share(url)
                return .none

            case .copyText(let magnetURL):
                state.toast = .copiedToClipboardSucceeded
                return .merge(
                    .run(operation: { _ in clipboardClient.saveText(magnetURL) }),
                    .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.success) })
                )

            case .presentTorrentActivity(let hash, let data):
                if let url = fileClient.saveTorrent(hash: hash, data: data) {
                    return .send(.presentShare(url))
                }
                return .none

            case .fetchTorrent(let hash, let torrentURL):
                return .run { send in
                    let response = await DataRequest(url: torrentURL).response()
                    await send(.fetchTorrentDone(hash, response))
                }
                .cancellable(id: CancelID.fetchTorrent)

            case .fetchTorrentDone(let hash, let result):
                if case .success(let data) = result, !data.isEmpty {
                    return .send(.presentTorrentActivity(hash, data))
                }
                return .none

            case .fetchGalleryTorrents(let gid, let token):
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                return .run { send in
                    let response = await GalleryTorrentsRequest(gid: gid, token: token).response()
                    await send(.fetchGalleryTorrentsDone(response))
                }
                .cancellable(id: CancelID.fetchGalleryTorrents)

            case .fetchGalleryTorrentsDone(let result):
                state.loadingState = .idle
                switch result {
                case .success(let torrents):
                    guard !torrents.isEmpty else {
                        state.loadingState = .failed(.notFound)
                        return .none
                    }
                    state.torrents = torrents
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none
            }
        }
        .haptics(
            unwrapping: \.destination,
            case: \.share,
            hapticsClient: hapticsClient
        )
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$toast, action: \.toast)
    }
}

extension TorrentsReducer.Destination.State: Equatable, Sendable {}
extension TorrentsReducer.Destination.Action: Equatable, Sendable {}
