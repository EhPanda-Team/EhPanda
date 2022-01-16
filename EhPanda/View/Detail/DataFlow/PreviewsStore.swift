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

    @BindableState var route: Route?
    var gallery: Gallery?
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

    case syncGalleryPreviews
    case syncPreviewConfig(PreviewConfig)
    case updateReadingProgress(Int)

    case fetchDatabaseInfos(String)
    case fetchDatabaseInfosDone(GalleryState)
    case fetchPreviews(Int)
    case fetchPreviewsDone(Result<[Int: String], AppError>)
}

struct PreviewsEnvironment {
    let databaseClient: DatabaseClient
}

let previewsReducer = Reducer<PreviewsState, PreviewsAction, PreviewsEnvironment> { state, action, environment in
    switch action {
    case .binding:
        return .none

    case .setNavigation(let route):
        state.route = route
        return .none

    case .syncGalleryPreviews:
        guard !state.galleryID.isEmpty else { return .none }
        return environment.databaseClient
            .updateGalleryPreviews(gid: state.galleryID, previews: state.previews).fireAndForget()

    case .syncPreviewConfig:
        guard !state.galleryID.isEmpty else { return .none }
        return environment.databaseClient
            .updatePreviewConfig(gid: state.galleryID, config: state.previewConfig).fireAndForget()

    case .updateReadingProgress(let progress):
        return environment.databaseClient
            .updateReadingProgress(gid: state.galleryID, progress: progress).fireAndForget()

    case .fetchDatabaseInfos(let gid):
        let gallery = environment.databaseClient.fetchGallery(gid)
        state.galleryID = gid
        state.gallery = gallery
        return environment.databaseClient.fetchGalleryState(state.galleryID)
                .map(PreviewsAction.fetchDatabaseInfosDone)

    case .fetchDatabaseInfosDone(let galleryState):
        if let previewConfig = galleryState.previewConfig {
            state.previewConfig = previewConfig
        }
        state.previews = galleryState.previews
        return .none

    case .fetchPreviews(let index):
        guard let galleryURL = state.gallery?.galleryURL, state.loadingState != .loading else { return .none }
        state.loadingState = .loading

        let pageNumber = state.previewConfig.pageNumber(index: index)
        let url = URLUtil.detailPage(url: galleryURL, pageNum: pageNumber)
        return GalleryPreviewsRequest(url: url).effect.map(PreviewsAction.fetchPreviewsDone)

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
