//
//  PreviewsStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/16.
//

import ComposableArchitecture

struct PreviewsState: Equatable {
    enum Route {
        case reading
    }
    struct CancelID: Hashable {
        let id = String(describing: PreviewsState.self)
    }

    @BindableState var route: Route?
    var galleryID = ""

    var previewConfig: PreviewConfig = .normal(rows: 4)
    var loadingState: LoadingState = .idle
    var previews = [Int: String]()

    mutating func insertPreviews(_ previews: [Int: String]) {
        self.previews = self.previews.merging(
            previews, uniquingKeysWith: { stored, _ in stored }
        )
    }
}

enum PreviewsAction: BindableAction {
    case binding(BindingAction<PreviewsState>)
    case setNavigation(PreviewsState.Route?)
    case clearSubStates

    case syncGalleryPreviews
    case updateReadingProgress(Int)

    case cancelFetching
    case fetchDatabaseInfos(String)
    case fetchDatabaseInfosDone(GalleryState)
    case fetchPreviews(String, Int)
    case fetchPreviewsDone(Result<[Int: String], AppError>)
}

struct PreviewsEnvironment {
    let databaseClient: DatabaseClient
}

let previewsReducer = Reducer<PreviewsState, PreviewsAction, PreviewsEnvironment> { state, action, environment in
    switch action {
    case .binding(\.$route):
        return state.route == nil ? .init(value: .clearSubStates) : .none

    case .binding:
        return .none

    case .setNavigation(let route):
        state.route = route
        return route == nil ? .init(value: .clearSubStates) : .none

    case .clearSubStates:
        return .none

    case .syncGalleryPreviews:
        guard !state.galleryID.isEmpty else { return .none }
        return environment.databaseClient
            .updateGalleryPreviews(gid: state.galleryID, previews: state.previews).fireAndForget()

    case .updateReadingProgress(let progress):
        guard !state.galleryID.isEmpty else { return .none }
        return environment.databaseClient
            .updateReadingProgress(gid: state.galleryID, progress: progress).fireAndForget()

    case .cancelFetching:
        return .cancel(id: PreviewsState.CancelID())

    case .fetchDatabaseInfos(let gid):
        let gallery = environment.databaseClient.fetchGallery(gid)
        state.galleryID = gid
        return environment.databaseClient.fetchGalleryState(gid)
                .map(PreviewsAction.fetchDatabaseInfosDone).cancellable(id: PreviewsState.CancelID())

    case .fetchDatabaseInfosDone(let galleryState):
        if let previewConfig = galleryState.previewConfig {
            state.previewConfig = previewConfig
        }
        state.previews = galleryState.previews
        return .none

    case .fetchPreviews(let galleryURL, let index):
        guard state.loadingState != .loading else { return .none }
        state.loadingState = .loading

        let pageNumber = state.previewConfig.pageNumber(index: index)
        let url = URLUtil.detailPage(url: galleryURL, pageNum: pageNumber)
        return GalleryPreviewsRequest(url: url).effect.map(PreviewsAction.fetchPreviewsDone)
            .cancellable(id: PreviewsState.CancelID())

    case .fetchPreviewsDone(let result):
        state.loadingState = .idle

        switch result {
        case .success(let previews):
            guard !previews.isEmpty else {
                state.loadingState = .failed(.notFound)
                return .none
            }
            state.insertPreviews(previews)
            return .init(value: .syncGalleryPreviews)
        case .failure(let error):
            state.loadingState = .failed(error)
        }
        return .none
    }
}
.binding()
