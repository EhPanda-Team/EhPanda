//
//  DetailStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/10.
//

import ComposableArchitecture

struct DetailState: Equatable, Identifiable {
    let galleryID: String
    var id: String { galleryID }

    init(galleryID: String) {
        self.galleryID = galleryID
    }

    @BindableState var userRating = 0
    @BindableState var showUserRating = false

    var apiKey = ""
    var galleryToken = ""

    var loadingState: LoadingState = .idle
    var gallery: Gallery?
    var galleryDetail: GalleryDetail?
    var galleryTags = [GalleryTag]()
    var galleryPreviews = [Int: String]()
    var galleryComments = [GalleryComment]()
}

enum DetailAction: BindableAction {
    case binding(BindingAction<DetailState>)

    case syncGalleryTags
    case syncGalleryDetail
    case syncGalleryPreviews
    case syncGalleryComments
    case syncPreviewConfig(PreviewConfig)
    case saveGalleryHistory

    case fetchDatabaseInfos
    case fetchDatabaseInfosDone(GalleryState)
    case fetchGalleryDetail
    case fetchGalleryDetailDone(Result<(GalleryDetail, GalleryState, APIKey, Greeting?), AppError>)

    case rateGallery(Int)
    case favorGallery(Int)
    case unfavorGallery
    case anyGalleryOpsDone(Result<Any, AppError>)
}

struct DetailEnvironment {
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
}

let detailReducer = Reducer<DetailState, DetailAction, DetailEnvironment> { state, action, environment in
    switch action {
    case .binding(\.$showUserRating):
        return state.showUserRating ? environment.hapticClient.generateFeedback(.soft).fireAndForget() : .none

    case .binding:
        return .none

    case .syncGalleryTags:
        return environment.databaseClient
            .updateGalleryTags(gid: state.galleryID, tags: state.galleryTags).fireAndForget()

    case .syncGalleryDetail:
        guard let detail = state.galleryDetail else { return .none }
        return environment.databaseClient.cacheGalleryDetail(detail).fireAndForget()

    case .syncGalleryPreviews:
        return environment.databaseClient
            .updateGalleryPreviews(gid: state.galleryID, previews: state.galleryPreviews).fireAndForget()

    case .syncGalleryComments:
        return environment.databaseClient
            .updateGalleryComments(gid: state.galleryID, comments: state.galleryComments).fireAndForget()

    case .syncPreviewConfig(let config):
        return environment.databaseClient
            .updatePreviewConfig(gid: state.galleryID, config: config).fireAndForget()

    case .saveGalleryHistory:
        return environment.databaseClient.updateLastOpenDate(gid: state.galleryID).fireAndForget()

    case .fetchDatabaseInfos:
        let gallery = environment.databaseClient.fetchGallery(state.galleryID)
        state.gallery = gallery
        state.galleryToken = gallery.token
        if let detail = environment.databaseClient.fetchGalleryDetail(state.galleryID) {
            state.galleryDetail = detail
        }
        return .merge(
            .init(value: .saveGalleryHistory),
            environment.databaseClient.fetchGalleryState(state.galleryID)
                .map(DetailAction.fetchDatabaseInfosDone)
        )

    case .fetchDatabaseInfosDone(let galleryState):
        state.galleryTags = galleryState.tags
        state.galleryPreviews = galleryState.previews
        state.galleryComments = galleryState.comments
        return .init(value: .fetchGalleryDetail)

    case .fetchGalleryDetail:
        guard state.loadingState != .loading else { return .none }
        state.loadingState = .loading
        let galleryURL = environment.databaseClient.fetchGallery(state.galleryID).galleryURL
        return GalleryDetailRequest(gid: state.galleryID, galleryURL: galleryURL)
            .effect.map(DetailAction.fetchGalleryDetailDone)

    case .fetchGalleryDetailDone(let result):
        state.loadingState = .idle
        switch result {
        case .success(let (galleryDetail, galleryState, apiKey, greeting)):
            // `greeting` should be handled somewhere!
            var effects: [Effect<DetailAction, Never>] = [
                .init(value: .syncGalleryTags),
                .init(value: .syncGalleryDetail),
                .init(value: .syncGalleryPreviews),
                .init(value: .syncGalleryComments)
            ]
            state.apiKey = apiKey
            state.galleryDetail = galleryDetail
            state.galleryTags = galleryState.tags
            state.galleryPreviews = galleryState.previews
            state.galleryComments = galleryState.comments
            state.userRating = Int(galleryDetail.userRating)
            if let config = galleryState.previewConfig {
                effects.append(.init(value: .syncPreviewConfig(config)))
            }
            return .merge(effects)
        case .failure(let error):
            state.loadingState = .failed(error)
        }
        return .none

    case .rateGallery(let rating):
        guard let apiuid = Int(environment.cookiesClient.apiuid), let gid = Int(state.galleryID) else { return .none }
        return RateGalleryRequest(
            apiuid: apiuid, apikey: state.apiKey, gid: gid,
            token: state.galleryToken, rating: rating
        )
        .effect.map(DetailAction.anyGalleryOpsDone)

    case .favorGallery(let favIndex):
        return FavorGalleryRequest(gid: state.galleryID, token: state.galleryToken, favIndex: favIndex)
            .effect.map(DetailAction.anyGalleryOpsDone)

    case .unfavorGallery:
        return UnfavorGalleryRequest(gid: state.galleryID).effect.map(DetailAction.anyGalleryOpsDone)

    case .anyGalleryOpsDone(let result):
        if case .success = result {
            return .merge(
                .init(value: .fetchGalleryDetail),
                environment.hapticClient.generateNotificationFeedback(.success).fireAndForget()
            )
        }
        return environment.hapticClient.generateNotificationFeedback(.error).fireAndForget()
    }
}
.binding()
