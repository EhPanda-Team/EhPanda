//
//  TorrentsReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/19.
//

import Foundation
import TTProgressHUD
import ComposableArchitecture

struct TorrentsReducer: ReducerProtocol {
    enum Route: Equatable {
        case hud
        case share(URL)
    }

    private enum CancelID: CaseIterable {
        case fetchTorrent, fetchGalleryTorrents
    }

    struct State: Equatable {
        @BindingState var route: Route?
        var torrents = [GalleryTorrent]()
        var loadingState: LoadingState = .idle
        var hudConfig: TTProgressHUDConfig = .copiedToClipboardSucceeded
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case setNavigation(Route)

        case copyText(String)
        case presentTorrentActivity(String, Data)

        case teardown
        case fetchTorrent(String, URL)
        case fetchTorrentDone(String, Result<Data, AppError>)
        case fetchGalleryTorrents(String, String)
        case fetchGalleryTorrentsDone(Result<[GalleryTorrent], AppError>)
    }

    @Dependency(\.clipboardClient) private var clipboardClient
    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.fileClient) private var fileClient

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return .none

            case .copyText(let magnetURL):
                state.route = .hud
                return .merge(
                    clipboardClient.saveText(magnetURL).fireAndForget(),
                    .fireAndForget({ hapticsClient.generateNotificationFeedback(.success) })
                )

            case .presentTorrentActivity(let hash, let data):
                if let url = fileClient.saveTorrent(hash: hash, data: data) {
                    return .init(value: .setNavigation(.share(url)))
                }
                return .none

            case .fetchTorrent(let hash, let torrentURL):
                return DataRequest(url: torrentURL).effect.map({ Action.fetchTorrentDone(hash, $0) })
                    .cancellable(id: CancelID.fetchTorrent)

            case .teardown:
                return .cancel(ids: CancelID.allCases)

            case .fetchTorrentDone(let hash, let result):
                if case .success(let data) = result, !data.isEmpty {
                    return .init(value: .presentTorrentActivity(hash, data))
                }
                return .none

            case .fetchGalleryTorrents(let gid, let token):
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                return GalleryTorrentsRequest(gid: gid, token: token)
                    .effect.map(Action.fetchGalleryTorrentsDone).cancellable(id: CancelID.fetchGalleryTorrents)

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
            unwrapping: \.route,
            case: /Route.share,
            hapticsClient: hapticsClient
        )
    }
}
