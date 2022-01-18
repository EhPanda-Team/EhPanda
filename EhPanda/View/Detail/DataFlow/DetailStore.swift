//
//  DetailStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/10.
//

import SwiftUI
import ComposableArchitecture

struct DetailState: Equatable, Identifiable {
    enum Route: Equatable {
        case archive
        case reading
        case torrents
        case previews
        case comments
        case draftComment
        case searchRequest(String)
        case galleryInfos(Gallery, GalleryDetail)
    }

    // IdentifiedArray requirement
    let id: String
    init(id: String = UUID().uuidString) {
        self.id = id
    }

    @BindableState var route: Route?
    var showFullTitle = false
    var showUserRating = false
    var userRating = 0

    var apiKey = ""
    var galleryID = ""
    var galleryToken = ""

    var loadingState: LoadingState = .idle
    var gallery: Gallery?
    var galleryDetail: GalleryDetail?
    var galleryTags = [GalleryTag]()
    var galleryPreviews = [Int: String]()
    var galleryComments = [GalleryComment]()

    var previewsState = PreviewsState()
    var commentsState = CommentsState()

    mutating func updateRating(value: DragGesture.Value) {
        let rating = Int(value.location.x / 31 * 2) + 1
        userRating = min(max(rating, 1), 10)
    }
}

enum DetailAction: BindableAction {
    case binding(BindingAction<DetailState>)
    case setNavigation(DetailState.Route?)
    case clearSubStates

    case toggleShowFullTitle
    case toggleShowUserRating
    case updateRating(DragGesture.Value)
    case confirmRating(DragGesture.Value)
    case confirmRatingDone

    case syncGalleryTags
    case syncGalleryDetail
    case syncGalleryPreviews
    case syncGalleryComments
    case syncPreviewConfig(PreviewConfig)
    case saveGalleryHistory
    case updateReadingProgress(Int)

    case fetchDatabaseInfos(String)
    case fetchDatabaseInfosDone(GalleryState)
    case fetchGalleryDetail
    case fetchGalleryDetailDone(Result<(GalleryDetail, GalleryState, APIKey, Greeting?), AppError>)

    case rateGallery
    case favorGallery(Int)
    case unfavorGallery
    case anyGalleryOpsDone(Result<Any, AppError>)

    case previews(PreviewsAction)
    case comments(CommentsAction)
}

struct DetailEnvironment {
    let urlClient: URLClient
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
    let uiApplicationClient: UIApplicationClient
}

let detailReducer = Reducer<DetailState, DetailAction, DetailEnvironment>.combine(
    .init { state, action, environment in
        switch action {
        case .binding(\.$route):
            return state.route == nil ? .init(value: .clearSubStates) : .none

        case .binding:
            return .none

        case .setNavigation(let route):
            state.route = route
            return route == nil ? .init(value: .clearSubStates) : .none

        case .clearSubStates:
            state.previewsState = .init()
            state.commentsState = .init()
            return .none

        case .toggleShowFullTitle:
            state.showFullTitle.toggle()
            return environment.hapticClient.generateFeedback(.soft).fireAndForget()

        case .toggleShowUserRating:
            state.showUserRating.toggle()
            return environment.hapticClient.generateFeedback(.soft).fireAndForget()

        case .updateRating(let value):
            state.updateRating(value: value)
            return .none

        case .confirmRating(let value):
            state.updateRating(value: value)
            return .merge(
                .init(value: .rateGallery),
                environment.hapticClient.generateFeedback(.soft).fireAndForget(),
                .init(value: .confirmRatingDone).delay(for: 1, scheduler: DispatchQueue.main).eraseToEffect()
            )

        case .confirmRatingDone:
            state.showUserRating = false
            return .none

        case .syncGalleryTags:
            guard !state.galleryID.isEmpty else { return .none }
            return environment.databaseClient
                .updateGalleryTags(gid: state.galleryID, tags: state.galleryTags).fireAndForget()

        case .syncGalleryDetail:
            guard !state.galleryID.isEmpty, let detail = state.galleryDetail else { return .none }
            return environment.databaseClient.cacheGalleryDetail(detail).fireAndForget()

        case .syncGalleryPreviews:
            guard !state.galleryID.isEmpty else { return .none }
            return environment.databaseClient
                .updateGalleryPreviews(gid: state.galleryID, previews: state.galleryPreviews).fireAndForget()

        case .syncGalleryComments:
            guard !state.galleryID.isEmpty else { return .none }
            return environment.databaseClient
                .updateGalleryComments(gid: state.galleryID, comments: state.galleryComments).fireAndForget()

        case .syncPreviewConfig(let config):
            guard !state.galleryID.isEmpty else { return .none }
            return environment.databaseClient
                .updatePreviewConfig(gid: state.galleryID, config: config).fireAndForget()

        case .saveGalleryHistory:
            guard !state.galleryID.isEmpty else { return .none }
            return environment.databaseClient.updateLastOpenDate(gid: state.galleryID).fireAndForget()

        case .updateReadingProgress(let progress):
            return environment.databaseClient
                .updateReadingProgress(gid: state.galleryID, progress: progress).fireAndForget()

        case .fetchDatabaseInfos(let gid):
            let gallery = environment.databaseClient.fetchGallery(gid)
            state.galleryID = gid
            state.gallery = gallery
            state.galleryToken = gallery.token
            if let detail = environment.databaseClient.fetchGalleryDetail(gid) {
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
            guard let galleryURL = state.gallery?.galleryURL, state.loadingState != .loading else { return .none }
            state.loadingState = .loading
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
                state.userRating = Int(galleryDetail.userRating) * 2
                if let config = galleryState.previewConfig {
                    effects.append(.init(value: .syncPreviewConfig(config)))
                }
                return .merge(effects)
            case .failure(let error):
                state.loadingState = .failed(error)
            }
            return .none

        case .rateGallery:
            guard let apiuid = Int(environment.cookiesClient.apiuid),
                  let gid = Int(state.galleryID)
            else { return .none }
            return RateGalleryRequest(
                apiuid: apiuid, apikey: state.apiKey, gid: gid,
                token: state.galleryToken, rating: state.userRating
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

        case .previews:
            return .none

        case .comments(.performCommentActionDone):
            return .init(value: .fetchGalleryDetail)

        case .comments:
            return .none
        }
    }
    .binding(),
    previewsReducer.pullback(
        state: \.previewsState,
        action: /DetailAction.previews,
        environment: {
            .init(
                databaseClient: $0.databaseClient
            )
        }
    ),
    commentsReducer.pullback(
        state: \.commentsState,
        action: /DetailAction.comments,
        environment: {
            .init(
                urlClient: $0.urlClient,
                hapticClient: $0.hapticClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient,
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    )
)
