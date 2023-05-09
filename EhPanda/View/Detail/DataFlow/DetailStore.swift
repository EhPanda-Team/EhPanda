//
//  DetailStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/10.
//

import SwiftUI
import Foundation
import ComposableArchitecture

struct DetailState: Equatable {
    enum Route: Equatable {
        case reading
        case archives(URL, URL)
        case torrents
        case previews
        case comments(URL)
        case share(URL)
        case postComment
        case newDawn(Greeting)
        case detailSearch(String)
        case tagDetail(TagDetail)
        case galleryInfos(Gallery, GalleryDetail)
    }
    struct CancelID: Hashable {
        let id = String(describing: DetailState.self)
    }

    init() {
        _commentsState = .init(nil)
        _detailSearchState = .init(nil)
    }

    @BindingState var route: Route?
    @BindingState var commentContent = ""
    @BindingState var postCommentFocused = false

    var showsNewDawnGreeting = false
    var showsUserRating = false
    var showsFullTitle = false
    var userRating = 0

    var apiKey = ""
    var loadingState: LoadingState = .idle
    var gallery: Gallery = .empty
    var galleryDetail: GalleryDetail?
    var galleryTags = [GalleryTag]()
    var galleryPreviewURLs = [Int: URL]()
    var galleryComments = [GalleryComment]()

    var readingState = ReadingState()
    var archivesState = ArchivesState()
    var torrentsState = TorrentsState()
    var previewsState = PreviewsState()
    @Heap var commentsState: CommentsState?
    var galleryInfosState = GalleryInfosState()
    @Heap var detailSearchState: DetailSearchState?

    mutating func updateRating(value: DragGesture.Value) {
        let rating = Int(value.location.x / 31 * 2) + 1
        userRating = min(max(rating, 1), 10)
    }
}

indirect enum DetailAction: BindableAction {
    case binding(BindingAction<DetailState>)
    case setNavigation(DetailState.Route?)
    case clearSubStates
    case onPostCommentAppear
    case onAppear(String, Bool)

    case toggleShowFullTitle
    case toggleShowUserRating
    case setCommentContent(String)
    case setPostCommentFocused(Bool)
    case updateRating(DragGesture.Value)
    case confirmRating(DragGesture.Value)
    case confirmRatingDone

    case syncGalleryTags
    case syncGalleryDetail
    case syncGalleryPreviewURLs
    case syncGalleryComments
    case syncGreeting(Greeting)
    case syncPreviewConfig(PreviewConfig)
    case saveGalleryHistory
    case updateReadingProgress(Int)

    case teardown
    case fetchDatabaseInfos(String)
    case fetchDatabaseInfosDone(GalleryState)
    case fetchGalleryDetail
    case fetchGalleryDetailDone(Result<(GalleryDetail, GalleryState, String, Greeting?), AppError>)

    case rateGallery
    case favorGallery(Int)
    case unfavorGallery
    case postComment(URL)
    case voteTag(String, Int)
    case anyGalleryOpsDone(Result<Any, AppError>)

    case reading(ReadingAction)
    case archives(ArchivesAction)
    case torrents(TorrentsAction)
    case previews(PreviewsAction)
    case comments(CommentsAction)
    case galleryInfos(GalleryInfosAction)
    case detailSearch(DetailSearchAction)
}

struct DetailEnvironment {
    let urlClient: URLClient
    let fileClient: FileClient
    let imageClient: ImageClient
    let deviceClient: DeviceClient
    let hapticsClient: HapticsClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
    let clipboardClient: ClipboardClient
    let appDelegateClient: AppDelegateClient
    let uiApplicationClient: UIApplicationClient
}

extension Reducer {
    static func recurse(
        _ reducer: @escaping
        (Reducer<DetailState, DetailAction, DetailEnvironment>)
        -> Reducer<DetailState, DetailAction, DetailEnvironment>
    )
    -> Reducer<DetailState, DetailAction, DetailEnvironment> {
        var `self`: Reducer<DetailState, DetailAction, DetailEnvironment>!
        self = Reducer { state, action, environment in
            reducer(self).run(&state, action, environment)
        }
        return self
    }
}

let detailReducer = Reducer<DetailState, DetailAction, DetailEnvironment>.recurse { (self) in
    Reducer<DetailState, DetailAction, DetailEnvironment>.combine(
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
                state.readingState = .init()
                state.archivesState = .init()
                state.torrentsState = .init()
                state.previewsState = .init()
                state.commentsState = .init()
                state.commentContent = .init()
                state.postCommentFocused = false
                state.galleryInfosState = .init()
                state.detailSearchState = .init()
                return .merge(
                    .init(value: .reading(.teardown)),
                    .init(value: .archives(.teardown)),
                    .init(value: .torrents(.teardown)),
                    .init(value: .previews(.teardown)),
                    .init(value: .comments(.teardown)),
                    .init(value: .detailSearch(.teardown))
                )

            case .onPostCommentAppear:
                return .init(value: .setPostCommentFocused(true))
                    .delay(for: .milliseconds(750), scheduler: DispatchQueue.main).eraseToEffect()

            case .onAppear(let gid, let showsNewDawnGreeting):
                state.showsNewDawnGreeting = showsNewDawnGreeting
                if state.detailSearchState == nil {
                    state.detailSearchState = .init()
                }
                if state.commentsState == nil {
                    state.commentsState = .init()
                }
                return .init(value: .fetchDatabaseInfos(gid))

            case .toggleShowFullTitle:
                state.showsFullTitle.toggle()
                return environment.hapticsClient.generateFeedback(.soft).fireAndForget()

            case .toggleShowUserRating:
                state.showsUserRating.toggle()
                return environment.hapticsClient.generateFeedback(.soft).fireAndForget()

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
                    environment.hapticsClient.generateFeedback(.soft).fireAndForget(),
                    .init(value: .confirmRatingDone).delay(for: 1, scheduler: DispatchQueue.main).eraseToEffect()
                )

            case .confirmRatingDone:
                state.showsUserRating = false
                return .none

            case .syncGalleryTags:
                return environment.databaseClient
                    .updateGalleryTags(gid: state.gallery.id, tags: state.galleryTags).fireAndForget()

            case .syncGalleryDetail:
                guard let detail = state.galleryDetail else { return .none }
                return environment.databaseClient.cacheGalleryDetail(detail).fireAndForget()

            case .syncGalleryPreviewURLs:
                return environment.databaseClient
                    .updatePreviewURLs(gid: state.gallery.id, previewURLs: state.galleryPreviewURLs).fireAndForget()

            case .syncGalleryComments:
                return environment.databaseClient
                    .updateComments(gid: state.gallery.id, comments: state.galleryComments).fireAndForget()

            case .syncGreeting(let greeting):
                return environment.databaseClient.updateGreeting(greeting).fireAndForget()

            case .syncPreviewConfig(let config):
                return environment.databaseClient
                    .updatePreviewConfig(gid: state.gallery.id, config: config).fireAndForget()

            case .saveGalleryHistory:
                return environment.databaseClient.updateLastOpenDate(gid: state.gallery.id).fireAndForget()

            case .updateReadingProgress(let progress):
                return environment.databaseClient
                    .updateReadingProgress(gid: state.gallery.id, progress: progress).fireAndForget()

            case .teardown:
                return .cancel(id: DetailState.CancelID())

            case .fetchDatabaseInfos(let gid):
                guard let gallery = environment.databaseClient.fetchGallery(gid: gid) else { return .none }
                state.gallery = gallery
                if let detail = environment.databaseClient.fetchGalleryDetail(gid: gid) {
                    state.galleryDetail = detail
                }
                return .merge(
                    .init(value: .saveGalleryHistory),
                    environment.databaseClient.fetchGalleryState(gid: state.gallery.id)
                        .map(DetailAction.fetchDatabaseInfosDone).cancellable(id: DetailState.CancelID())
                )

            case .fetchDatabaseInfosDone(let galleryState):
                state.galleryTags = galleryState.tags
                state.galleryPreviewURLs = galleryState.previewURLs
                state.galleryComments = galleryState.comments
                return .init(value: .fetchGalleryDetail)

            case .fetchGalleryDetail:
                guard state.loadingState != .loading,
                      let galleryURL = state.gallery.galleryURL
                else { return .none }
                state.loadingState = .loading
                return GalleryDetailRequest(gid: state.gallery.id, galleryURL: galleryURL)
                    .effect.map(DetailAction.fetchGalleryDetailDone).cancellable(id: DetailState.CancelID())

            case .fetchGalleryDetailDone(let result):
                state.loadingState = .idle
                switch result {
                case .success(let (galleryDetail, galleryState, apiKey, greeting)):
                    var effects: [EffectTask<DetailAction>] = [
                        .init(value: .syncGalleryTags),
                        .init(value: .syncGalleryDetail),
                        .init(value: .syncGalleryPreviewURLs),
                        .init(value: .syncGalleryComments)
                    ]
                    state.apiKey = apiKey
                    state.galleryDetail = galleryDetail
                    state.galleryTags = galleryState.tags
                    state.galleryPreviewURLs = galleryState.previewURLs
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
                guard let apiuid = Int(environment.cookiesClient.apiuid), let gid = Int(state.gallery.id)
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

            case .voteTag(let tag, let vote):
                guard let apiuid = Int(environment.cookiesClient.apiuid), let gid = Int(state.gallery.id)
                else { return .none }
                return VoteGalleryTagRequest(
                    apiuid: apiuid, apikey: state.apiKey, gid: gid, token: state.gallery.token, tag: tag, vote: vote
                )
                .effect.map(DetailAction.anyGalleryOpsDone).cancellable(id: DetailState.CancelID())

            case .anyGalleryOpsDone(let result):
                if case .success = result {
                    return .merge(
                        .init(value: .fetchGalleryDetail),
                        environment.hapticsClient.generateNotificationFeedback(.success).fireAndForget()
                    )
                }
                return environment.hapticsClient.generateNotificationFeedback(.error).fireAndForget()

            case .reading(.onPerformDismiss):
                return .init(value: .setNavigation(nil))

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

            case .comments(.detail(let recursiveAction)):
                guard state.commentsState != nil else { return .none }
                return self.run(&state.commentsState!.detailState, recursiveAction, environment)
                    .map({ DetailAction.comments(.detail($0)) })

            case .comments:
                return .none

            case .galleryInfos:
                return .none

            case .detailSearch(.detail(let recursiveAction)):
                guard state.detailSearchState != nil else { return .none }
                return self.run(&state.detailSearchState!.detailState, recursiveAction, environment)
                    .map({ DetailAction.detailSearch(.detail($0)) })

            case .detailSearch:
                return .none
            }
        }
        .haptics(
            unwrapping: \.route,
            case: /DetailState.Route.detailSearch,
            hapticsClient: \.hapticsClient,
            style: .soft
        )
        .haptics(
            unwrapping: \.route,
            case: /DetailState.Route.postComment,
            hapticsClient: \.hapticsClient
        )
        .haptics(
            unwrapping: \.route,
            case: /DetailState.Route.tagDetail,
            hapticsClient: \.hapticsClient
        )
        .haptics(
            unwrapping: \.route,
            case: /DetailState.Route.torrents,
            hapticsClient: \.hapticsClient
        )
        .haptics(
            unwrapping: \.route,
            case: /DetailState.Route.archives,
            hapticsClient: \.hapticsClient
        )
        .haptics(
            unwrapping: \.route,
            case: /DetailState.Route.reading,
            hapticsClient: \.hapticsClient
        )
        .haptics(
            unwrapping: \.route,
            case: /DetailState.Route.share,
            hapticsClient: \.hapticsClient
        )
        .binding(),
        readingReducer.pullback(
            state: \.readingState,
            action: /DetailAction.reading,
            environment: {
                .init(
                    urlClient: $0.urlClient,
                    imageClient: $0.imageClient,
                    deviceClient: $0.deviceClient,
                    hapticsClient: $0.hapticsClient,
                    cookiesClient: $0.cookiesClient,
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
                    hapticsClient: $0.hapticsClient,
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
                    hapticsClient: $0.hapticsClient,
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
                    hapticsClient: $0.hapticsClient,
                    cookiesClient: $0.cookiesClient,
                    databaseClient: $0.databaseClient,
                    clipboardClient: $0.clipboardClient,
                    appDelegateClient: $0.appDelegateClient
                )
            }
        ),
        commentsReducer.optional().pullback(
            state: \.commentsState,
            action: /DetailAction.comments,
            environment: {
                .init(
                    urlClient: $0.urlClient,
                    fileClient: $0.fileClient,
                    imageClient: $0.imageClient,
                    deviceClient: $0.deviceClient,
                    hapticsClient: $0.hapticsClient,
                    cookiesClient: $0.cookiesClient,
                    databaseClient: $0.databaseClient,
                    clipboardClient: $0.clipboardClient,
                    appDelegateClient: $0.appDelegateClient,
                    uiApplicationClient: $0.uiApplicationClient
                )
            }
        ),
        detailSearchReducer.optional().pullback(
            state: \.detailSearchState,
            action: /DetailAction.detailSearch,
            environment: {
                .init(
                    urlClient: $0.urlClient,
                    fileClient: $0.fileClient,
                    imageClient: $0.imageClient,
                    deviceClient: $0.deviceClient,
                    hapticsClient: $0.hapticsClient,
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
                    hapticsClient: $0.hapticsClient,
                    clipboardClient: $0.clipboardClient
                )
            }
        )
    )
}
