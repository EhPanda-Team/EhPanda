//
//  DetailStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/10.
//

import SwiftUI
import ComposableArchitecture

struct DetailState: Equatable {
    enum Route: Equatable {
        case reading
        case archives
        case torrents
        case previews
        case comments
        case share(URL)
        case postComment
        case newDawn(Greeting)
        case galleryInfos(Gallery, GalleryDetail)
    }
    struct CancelID: Hashable {
        let id = String(describing: DetailState.self)
    }

    @BindableState var route: Route?
    @BindableState var commentContent = ""
    @BindableState var postCommentFocused = false

    var showsNewDawnGreeting = false
    var showsUserRating = false
    var showsFullTitle = false
    var userRating = 0

    var apiKey = ""
    var loadingState: LoadingState = .idle
    var gallery: Gallery = .empty
    var galleryDetail: GalleryDetail?
    var galleryTags = [GalleryTag]()
    var galleryPreviews = [Int: String]()
    var galleryComments = [GalleryComment]()

    var readingState = ReadingState(gallery: .empty)
    var archivesState = ArchivesState()
    var torrentsState = TorrentsState()
    var previewsState = PreviewsState(gallery: .empty)
    var commentsState = CommentsState()
    var galleryInfosState = GalleryInfosState()

    mutating func updateRating(value: DragGesture.Value) {
        let rating = Int(value.location.x / 31 * 2) + 1
        userRating = min(max(rating, 1), 10)
    }
}

enum DetailAction: BindableAction {
    case binding(BindingAction<DetailState>)
    case setNavigation(DetailState.Route?)
    case setupPreviewsState
    case setupReadingState
    case clearSubStates
    case onPostCommentAppear
    case onAppear(String, Bool)
    case onNavigateSearchRequest(String)

    case toggleShowFullTitle
    case toggleShowUserRating
    case setCommentContent(String)
    case setPostCommentFocused(Bool)
    case updateRating(DragGesture.Value)
    case confirmRating(DragGesture.Value)
    case confirmRatingDone

    case syncGalleryTags
    case syncGalleryDetail
    case syncGalleryPreviews
    case syncGalleryComments
    case syncGreeting(Greeting)
    case syncPreviewConfig(PreviewConfig)
    case saveGalleryHistory
    case updateReadingProgress(Int)

    case cancelFetching
    case fetchDatabaseInfos(String)
    case fetchDatabaseInfosDone(GalleryState)
    case fetchGalleryDetail
    case fetchGalleryDetailDone(Result<(GalleryDetail, GalleryState, APIKey, Greeting?), AppError>)

    case rateGallery
    case favorGallery(Int)
    case unfavorGallery
    case postComment(String)
    case anyGalleryOpsDone(Result<Any, AppError>)

    case reading(ReadingAction)
    case archives(ArchivesAction)
    case torrents(TorrentsAction)
    case previews(PreviewsAction)
    case comments(CommentsAction)
    case galleryInfos(GalleryInfosAction)
}

struct DetailEnvironment {
    let urlClient: URLClient
    let fileClient: FileClient
    let imageClient: ImageClient
    let deviceClient: DeviceClient
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
    let clipboardClient: ClipboardClient
    let appDelegateClient: AppDelegateClient
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

        case .setupPreviewsState:
            state.previewsState = .init(gallery: state.gallery)
            return .none

        case .setupReadingState:
            state.readingState = .init(gallery: state.gallery)
            return .none

        case .clearSubStates:
            state.archivesState = .init()
            state.torrentsState = .init()
            state.commentsState = .init()
            state.commentContent = .init()
            state.postCommentFocused = false
            state.galleryInfosState = .init()
            return .merge(
                .init(value: .setupPreviewsState),
                .init(value: .setupReadingState),
                .init(value: .reading(.teardown)),
                .init(value: .archives(.cancelFetching)),
                .init(value: .torrents(.cancelFetching)),
                .init(value: .previews(.cancelFetching)),
                .init(value: .comments(.cancelFetching))
            )

        case .onPostCommentAppear:
            return .init(value: .setPostCommentFocused(true))
                .delay(for: .milliseconds(750), scheduler: DispatchQueue.main).eraseToEffect()

        case .onAppear(let gid, let showsNewDawnGreeting):
            state.showsNewDawnGreeting = showsNewDawnGreeting
            return .init(value: .fetchDatabaseInfos(gid))

        case .onNavigateSearchRequest:
            return .none

        case .toggleShowFullTitle:
            state.showsFullTitle.toggle()
            return environment.hapticClient.generateFeedback(.soft).fireAndForget()

        case .toggleShowUserRating:
            state.showsUserRating.toggle()
            return environment.hapticClient.generateFeedback(.soft).fireAndForget()

        case .setCommentContent(let content):
            state.commentContent = content
            return .none

        case .setPostCommentFocused(let isFocused):
            state.postCommentFocused = isFocused
            return .none

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
            state.showsUserRating = false
            return .none

        case .syncGalleryTags:
            guard state.gallery.id.isValidGID else { return .none }
            return environment.databaseClient
                .updateGalleryTags(gid: state.gallery.id, tags: state.galleryTags).fireAndForget()

        case .syncGalleryDetail:
            guard state.gallery.id.isValidGID, let detail = state.galleryDetail else { return .none }
            return environment.databaseClient.cacheGalleryDetail(detail).fireAndForget()

        case .syncGalleryPreviews:
            guard state.gallery.id.isValidGID else { return .none }
            return environment.databaseClient
                .updatePreviews(gid: state.gallery.id, previews: state.galleryPreviews).fireAndForget()

        case .syncGalleryComments:
            guard state.gallery.id.isValidGID else { return .none }
            return environment.databaseClient
                .updateComments(gid: state.gallery.id, comments: state.galleryComments).fireAndForget()

        case .syncGreeting(let greeting):
            return environment.databaseClient.updateGreeting(greeting).fireAndForget()

        case .syncPreviewConfig(let config):
            guard state.gallery.id.isValidGID else { return .none }
            return environment.databaseClient
                .updatePreviewConfig(gid: state.gallery.id, config: config).fireAndForget()

        case .saveGalleryHistory:
            guard state.gallery.id.isValidGID else { return .none }
            return environment.databaseClient.updateLastOpenDate(gid: state.gallery.id).fireAndForget()

        case .updateReadingProgress(let progress):
            return environment.databaseClient
                .updateReadingProgress(gid: state.gallery.id, progress: progress).fireAndForget()

        case .cancelFetching:
            return .cancel(id: DetailState.CancelID())

        case .fetchDatabaseInfos(let gid):
            guard let gallery = environment.databaseClient.fetchGallery(gid) else { return .none }
            state.gallery = gallery
            if let detail = environment.databaseClient.fetchGalleryDetail(gid) {
                state.galleryDetail = detail
            }
            return .merge(
                .init(value: .saveGalleryHistory),
                environment.databaseClient.fetchGalleryState(state.gallery.id)
                    .map(DetailAction.fetchDatabaseInfosDone).cancellable(id: DetailState.CancelID())
            )

        case .fetchDatabaseInfosDone(let galleryState):
            state.galleryTags = galleryState.tags
            state.galleryPreviews = galleryState.previews
            state.galleryComments = galleryState.comments
            return .merge(
                .init(value: .fetchGalleryDetail),
                .init(value: .setupPreviewsState),
                .init(value: .setupReadingState)
            )

        case .fetchGalleryDetail:
            guard state.loadingState != .loading else { return .none }
            state.loadingState = .loading
            return GalleryDetailRequest(gid: state.gallery.id, galleryURL: state.gallery.galleryURL)
                .effect.map(DetailAction.fetchGalleryDetailDone).cancellable(id: DetailState.CancelID())

        case .fetchGalleryDetailDone(let result):
            state.loadingState = .idle
            switch result {
            case .success(let (galleryDetail, galleryState, apiKey, greeting)):
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
                if let greeting = greeting {
                    effects.append(.init(value: .syncGreeting(greeting)))
                    if !greeting.gainedNothing && state.showsNewDawnGreeting {
                        effects.append(.init(value: .setNavigation(.newDawn(greeting))))
                    }
                }
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
                  let gid = Int(state.gallery.id)
            else { return .none }
            return RateGalleryRequest(
                apiuid: apiuid, apikey: state.apiKey, gid: gid,
                token: state.gallery.token, rating: state.userRating
            )
            .effect.map(DetailAction.anyGalleryOpsDone).cancellable(id: DetailState.CancelID())

        case .favorGallery(let favIndex):
            return FavorGalleryRequest(gid: state.gallery.id, token: state.gallery.token, favIndex: favIndex)
                .effect.map(DetailAction.anyGalleryOpsDone).cancellable(id: DetailState.CancelID())

        case .unfavorGallery:
            return UnfavorGalleryRequest(gid: state.gallery.id).effect.map(DetailAction.anyGalleryOpsDone)
                .cancellable(id: DetailState.CancelID())

        case .postComment(let galleryURL):
            guard !state.commentContent.isEmpty else { return .none }
            return CommentGalleryRequest(content: state.commentContent, galleryURL: galleryURL)
                .effect.map(DetailAction.anyGalleryOpsDone).cancellable(id: DetailState.CancelID())

        case .anyGalleryOpsDone(let result):
            if case .success = result {
                return .merge(
                    .init(value: .fetchGalleryDetail),
                    environment.hapticClient.generateNotificationFeedback(.success).fireAndForget()
                )
            }
            return environment.hapticClient.generateNotificationFeedback(.error).fireAndForget()

        case .reading:
            return .none

        case .archives:
            return .none

        case .torrents:
            return .none

        case .previews:
            return .none

        case .comments(.performCommentActionDone(let result)):
            return .init(value: .anyGalleryOpsDone(result))

        case .comments:
            return .none

        case .galleryInfos:
            return .none
        }
    }
    .binding(),
    readingReducer.pullback(
        state: \.readingState,
        action: /DetailAction.reading,
        environment: {
            .init(
                urlClient: $0.urlClient,
                imageClient: $0.imageClient,
                deviceClient: $0.deviceClient,
                hapticClient: $0.hapticClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                appDelegateClient: $0.appDelegateClient
            )
        }
    ),
    archivesReducer.pullback(
        state: \.archivesState,
        action: /DetailAction.archives,
        environment: {
            .init(
                hapticClient: $0.hapticClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient
            )
        }
    ),
    torrentsReducer.pullback(
        state: \.torrentsState,
        action: /DetailAction.torrents,
        environment: {
            .init(
                fileClient: $0.fileClient,
                hapticClient: $0.hapticClient,
                clipboardClient: $0.clipboardClient
            )
        }
    ),
    previewsReducer.pullback(
        state: \.previewsState,
        action: /DetailAction.previews,
        environment: {
            .init(
                urlClient: $0.urlClient,
                imageClient: $0.imageClient,
                deviceClient: $0.deviceClient,
                hapticClient: $0.hapticClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                appDelegateClient: $0.appDelegateClient
            )
        }
    ),
    commentsReducer.pullback(
        state: \.commentsState,
        action: /DetailAction.comments,
        environment: {
            .init(
                urlClient: $0.urlClient,
                fileClient: $0.fileClient,
                imageClient: $0.imageClient,
                deviceClient: $0.deviceClient,
                hapticClient: $0.hapticClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                appDelegateClient: $0.appDelegateClient,
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    ),
    galleryInfosReducer.pullback(
        state: \.galleryInfosState,
        action: /DetailAction.galleryInfos,
        environment: {
            .init(
                hapticClient: $0.hapticClient,
                clipboardClient: $0.clipboardClient
            )
        }
    )
)
