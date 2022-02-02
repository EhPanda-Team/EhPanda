//
//  TorrentsStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/19.
//

import Foundation
import TTProgressHUD
import ComposableArchitecture

struct TorrentsState: Equatable {
    enum Route: Equatable {
        case hud
        case share(URL)
    }
    struct CancelID: Hashable {
        let id = String(describing: TorrentsState.self)
    }

    @BindableState var route: Route?
    var torrents = [GalleryTorrent]()
    var loadingState: LoadingState = .idle
    var hudConfig: TTProgressHUDConfig = .copiedToClipboardSucceeded
}

enum TorrentsAction: BindableAction {
    case binding(BindingAction<TorrentsState>)
    case setNavigation(TorrentsState.Route)

    case copyText(String)
    case presentTorrentActivity(String, Data)

    case cancelFetching
    case fetchTorrent(String, URL)
    case fetchTorrentDone(String, Result<Data, AppError>)
    case fetchGalleryTorrents(String, String)
    case fetchGalleryTorrentsDone(Result<[GalleryTorrent], AppError>)
}

struct TorrentsEnvironment {
    let fileClient: FileClient
    let hapticClient: HapticClient
    let clipboardClient: ClipboardClient
}

let torrentsReducer = Reducer<TorrentsState, TorrentsAction, TorrentsEnvironment> { state, action, environment in
    switch action {
    case .binding:
        return .none

    case .setNavigation(let route):
        state.route = route
        return .none

    case .copyText(let magnetURL):
        state.route = .hud
        return .merge(
            environment.clipboardClient.saveText(magnetURL).fireAndForget(),
            environment.hapticClient.generateNotificationFeedback(.success).fireAndForget()
        )

    case .presentTorrentActivity(let hash, let data):
        if let url = environment.fileClient.saveTorrent(hash: hash, data: data) {
            return .init(value: .setNavigation(.share(url)))
        }
        return .none

    case .fetchTorrent(let hash, let torrentURL):
        return DataRequest(url: torrentURL).effect.map({ TorrentsAction.fetchTorrentDone(hash, $0) })
            .cancellable(id: TorrentsState.CancelID())

    case .cancelFetching:
        return .cancel(id: TorrentsState.CancelID())

    case .fetchTorrentDone(let hash, let result):
        if case .success(let data) = result, !data.isEmpty {
            return .init(value: .presentTorrentActivity(hash, data))
        }
        return .none

    case .fetchGalleryTorrents(let gid, let token):
        guard state.loadingState != .loading else { return .none }
        state.loadingState = .loading
        return GalleryTorrentsRequest(gid: gid, token: token)
            .effect.map(TorrentsAction.fetchGalleryTorrentsDone).cancellable(id: TorrentsState.CancelID())

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
    case: /TorrentsState.Route.share,
    hapticClient: \.hapticClient
)
.binding()
