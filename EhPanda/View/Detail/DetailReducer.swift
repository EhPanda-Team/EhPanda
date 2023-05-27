//
//  DetailReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/10.
//

import SwiftUI
import Foundation
import ComposableArchitecture

struct DetailReducer: ReducerProtocol {
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

    private enum CancelID: CaseIterable {
        case fetchDatabaseInfos, fetchGalleryDetail, rateGallery, favorGallery, unfavorGallery, postComment, voteTag
    }

    struct State: Equatable {
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

        var readingState = ReadingReducer.State()
        var archivesState = ArchivesReducer.State()
        var torrentsState = TorrentsReducer.State()
        var previewsState = PreviewsReducer.State()
        @Heap var commentsState: CommentsReducer.State?
        var galleryInfosState = GalleryInfosReducer.State()
        @Heap var detailSearchState: DetailSearchReducer.State?

        init() {
            _commentsState = .init(nil)
            _detailSearchState = .init(nil)
        }

        mutating func updateRating(value: DragGesture.Value) {
            let rating = Int(value.location.x / 31 * 2) + 1
            userRating = min(max(rating, 1), 10)
        }
    }

    indirect enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
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

        case reading(ReadingReducer.Action)
        case archives(ArchivesReducer.Action)
        case torrents(TorrentsReducer.Action)
        case previews(PreviewsReducer.Action)
        case comments(CommentsReducer.Action)
        case galleryInfos(GalleryInfosReducer.Action)
        case detailSearch(DetailSearchReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.cookieClient) private var cookieClient

    var body: some ReducerProtocol<State, Action> {
        RecurseReducer { (self) in
            BindingReducer()

            Reduce { state, action in
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
                    return .fireAndForget({ hapticsClient.generateFeedback(.soft) })

                case .toggleShowUserRating:
                    state.showsUserRating.toggle()
                    return .fireAndForget({ hapticsClient.generateFeedback(.soft) })

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
                        .fireAndForget({ hapticsClient.generateFeedback(.soft) }),
                        .init(value: .confirmRatingDone).delay(for: 1, scheduler: DispatchQueue.main).eraseToEffect()
                    )

                case .confirmRatingDone:
                    state.showsUserRating = false
                    return .none

                case .syncGalleryTags:
                    return databaseClient
                        .updateGalleryTags(gid: state.gallery.id, tags: state.galleryTags).fireAndForget()

                case .syncGalleryDetail:
                    guard let detail = state.galleryDetail else { return .none }
                    return databaseClient.cacheGalleryDetail(detail).fireAndForget()

                case .syncGalleryPreviewURLs:
                    return databaseClient
                        .updatePreviewURLs(gid: state.gallery.id, previewURLs: state.galleryPreviewURLs).fireAndForget()

                case .syncGalleryComments:
                    return databaseClient
                        .updateComments(gid: state.gallery.id, comments: state.galleryComments).fireAndForget()

                case .syncGreeting(let greeting):
                    return databaseClient.updateGreeting(greeting).fireAndForget()

                case .syncPreviewConfig(let config):
                    return databaseClient
                        .updatePreviewConfig(gid: state.gallery.id, config: config).fireAndForget()

                case .saveGalleryHistory:
                    return databaseClient.updateLastOpenDate(gid: state.gallery.id).fireAndForget()

                case .updateReadingProgress(let progress):
                    return databaseClient
                        .updateReadingProgress(gid: state.gallery.id, progress: progress).fireAndForget()

                case .teardown:
                    return .cancel(ids: CancelID.allCases)

                case .fetchDatabaseInfos(let gid):
                    guard let gallery = databaseClient.fetchGallery(gid: gid) else { return .none }
                    state.gallery = gallery
                    if let detail = databaseClient.fetchGalleryDetail(gid: gid) {
                        state.galleryDetail = detail
                    }
                    return .merge(
                        .init(value: .saveGalleryHistory),
                        databaseClient.fetchGalleryState(gid: state.gallery.id)
                            .map(Action.fetchDatabaseInfosDone).cancellable(id: CancelID.fetchDatabaseInfos)
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
                        .effect.map(Action.fetchGalleryDetailDone).cancellable(id: CancelID.fetchGalleryDetail)

                case .fetchGalleryDetailDone(let result):
                    state.loadingState = .idle
                    switch result {
                    case .success(let (galleryDetail, galleryState, apiKey, greeting)):
                        var effects: [EffectTask<Action>] = [
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
                    guard let apiuid = Int(cookieClient.apiuid), let gid = Int(state.gallery.id)
                    else { return .none }
                    return RateGalleryRequest(
                        apiuid: apiuid, apikey: state.apiKey, gid: gid,
                        token: state.gallery.token, rating: state.userRating
                    )
                    .effect.map(Action.anyGalleryOpsDone).cancellable(id: CancelID.rateGallery)

                case .favorGallery(let favIndex):
                    return FavorGalleryRequest(gid: state.gallery.id, token: state.gallery.token, favIndex: favIndex)
                        .effect.map(Action.anyGalleryOpsDone).cancellable(id: CancelID.favorGallery)

                case .unfavorGallery:
                    return UnfavorGalleryRequest(gid: state.gallery.id).effect.map(Action.anyGalleryOpsDone)
                        .cancellable(id: CancelID.unfavorGallery)

                case .postComment(let galleryURL):
                    guard !state.commentContent.isEmpty else { return .none }
                    return CommentGalleryRequest(content: state.commentContent, galleryURL: galleryURL)
                        .effect.map(Action.anyGalleryOpsDone).cancellable(id: CancelID.postComment)

                case .voteTag(let tag, let vote):
                    guard let apiuid = Int(cookieClient.apiuid), let gid = Int(state.gallery.id)
                    else { return .none }
                    return VoteGalleryTagRequest(
                        apiuid: apiuid, apikey: state.apiKey, gid: gid, token: state.gallery.token, tag: tag, vote: vote
                    )
                    .effect.map(Action.anyGalleryOpsDone).cancellable(id: CancelID.voteTag)

                case .anyGalleryOpsDone(let result):
                    if case .success = result {
                        return .merge(
                            .init(value: .fetchGalleryDetail),
                            .fireAndForget({ hapticsClient.generateNotificationFeedback(.success) })
                        )
                    }
                    return .fireAndForget({ hapticsClient.generateNotificationFeedback(.error) })

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
                    return self.reduce(into: &state.commentsState!.detailState, action: recursiveAction)
                        .map({ Action.comments(.detail($0)) })

                case .comments:
                    return .none

                case .galleryInfos:
                    return .none

                case .detailSearch(.detail(let recursiveAction)):
                    guard state.detailSearchState != nil else { return .none }
                    return self.reduce(into: &state.detailSearchState!.detailState, action: recursiveAction)
                        .map({ Action.detailSearch(.detail($0)) })

                case .detailSearch:
                    return .none
                }
            }
        }
        .ifLet(
            \.commentsState,
            action: /Action.comments,
            then: CommentsReducer.init
        )
        .ifLet(
            \.detailSearchState,
            action: /Action.detailSearch,
            then: DetailSearchReducer.init
        )
        .haptics(
            unwrapping: \.route,
            case: /Route.detailSearch,
            hapticsClient: hapticsClient,
            style: .soft
        )
        .haptics(
            unwrapping: \.route,
            case: /Route.postComment,
            hapticsClient: hapticsClient
        )
        .haptics(
            unwrapping: \.route,
            case: /Route.tagDetail,
            hapticsClient: hapticsClient
        )
        .haptics(
            unwrapping: \.route,
            case: /Route.torrents,
            hapticsClient: hapticsClient
        )
        .haptics(
            unwrapping: \.route,
            case: /Route.archives,
            hapticsClient: hapticsClient
        )
        .haptics(
            unwrapping: \.route,
            case: /Route.reading,
            hapticsClient: hapticsClient
        )
        .haptics(
            unwrapping: \.route,
            case: /Route.share,
            hapticsClient: hapticsClient
        )

        Scope(state: \.readingState, action: /Action.reading, child: ReadingReducer.init)
        Scope(state: \.archivesState, action: /Action.archives, child: ArchivesReducer.init)
        Scope(state: \.torrentsState, action: /Action.torrents, child: TorrentsReducer.init)
        Scope(state: \.previewsState, action: /Action.previews, child: PreviewsReducer.init)
        Scope(state: \.galleryInfosState, action: /Action.galleryInfos, child: GalleryInfosReducer.init)
    }
}
