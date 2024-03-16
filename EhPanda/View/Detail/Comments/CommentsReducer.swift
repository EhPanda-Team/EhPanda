//
//  CommentsReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/16.
//

import Foundation
import TTProgressHUD
import ComposableArchitecture

struct CommentsReducer: Reducer {
    enum Route: Equatable {
        case hud
        case detail(String)
        case postComment(String)
    }

    private enum CancelID: CaseIterable {
        case postComment, voteComment, fetchGallery
    }

    struct State: Equatable {
        @BindingState var route: Route?
        @BindingState var commentContent = ""
        @BindingState var postCommentFocused = false

        var hudConfig: TTProgressHUDConfig = .loading
        var scrollCommentID: String?
        var scrollRowOpacity: Double = 1

        @Heap var detailState: DetailReducer.State!

        init() {
            _detailState = .init(.init())
        }
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case clearSubStates
        case clearScrollCommentID

        case setHUDConfig(TTProgressHUDConfig)
        case setPostCommentFocused(Bool)
        case setScrollRowOpacity(Double)
        case setCommentContent(String)
        case performScrollOpacityEffect
        case handleCommentLink(URL)
        case handleGalleryLink(URL)
        case onPostCommentAppear
        case onAppear

        case updateReadingProgress(String, Int)

        case teardown
        case postComment(URL, String? = nil)
        case voteComment(String, String, String, String, Int)
        case performCommentActionDone(Result<Any, AppError>)
        case fetchGallery(URL, Bool)
        case fetchGalleryDone(URL, Result<Gallery, AppError>)

        case detail(DetailReducer.Action)
    }

    @Dependency(\.uiApplicationClient) private var uiApplicationClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.cookieClient) private var cookieClient
    @Dependency(\.urlClient) private var urlClient

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.$route):
                return state.route == nil ? Effect.send(.clearSubStates) : .none

            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil ? Effect.send(.clearSubStates) : .none

            case .clearSubStates:
                state.detailState = .init()
                state.commentContent = .init()
                state.postCommentFocused = false
                return Effect.send(.detail(.teardown))

            case .clearScrollCommentID:
                state.scrollCommentID = nil
                return .none

            case .setHUDConfig(let config):
                state.hudConfig = config
                return .none

            case .setPostCommentFocused(let isFocused):
                state.postCommentFocused = isFocused
                return .none

            case .setScrollRowOpacity(let opacity):
                state.scrollRowOpacity = opacity
                return .none

            case .setCommentContent(let content):
                state.commentContent = content
                return .none

            case .performScrollOpacityEffect:
                return .merge(
                    Effect.publisher {
                        Effect.send(.setScrollRowOpacity(0.25))
                            .delay(for: .milliseconds(750), scheduler: DispatchQueue.main)
                    },
                    Effect.publisher {
                        Effect.send(.setScrollRowOpacity(1))
                            .delay(for: .milliseconds(1250), scheduler: DispatchQueue.main)
                    },
                    Effect.publisher {
                        Effect.send(.clearScrollCommentID)
                            .delay(for: .milliseconds(2000), scheduler: DispatchQueue.main)
                    }
                )

            case .handleCommentLink(let url):
                guard urlClient.checkIfHandleable(url) else {
                    return uiApplicationClient.openURL(url).fireAndForget()
                }
                let (isGalleryImageURL, _, _) = urlClient.analyzeURL(url)
                let gid = urlClient.parseGalleryID(url)
                guard databaseClient.fetchGallery(gid: gid) == nil else {
                    return Effect.send(.handleGalleryLink(url))
                }
                return Effect.send(.fetchGallery(url, isGalleryImageURL))

            case .handleGalleryLink(let url):
                let (_, pageIndex, commentID) = urlClient.analyzeURL(url)
                let gid = urlClient.parseGalleryID(url)
                var effects = [Effect<Action>]()
                if let pageIndex = pageIndex {
                    effects.append(Effect.send(.updateReadingProgress(gid, pageIndex)))
                    effects.append(
                        Effect.publisher {
                            Effect.send(.detail(.setNavigation(.reading)))
                                .delay(for: .milliseconds(750), scheduler: DispatchQueue.main)
                        }
                    )
                } else if let commentID = commentID {
                    state.detailState.commentsState?.scrollCommentID = commentID
                    effects.append(
                        Effect.publisher {
                            Effect.send(.detail(.setNavigation(.comments(url))))
                                .delay(for: .milliseconds(750), scheduler: DispatchQueue.main)
                        }
                    )
                }
                effects.append(Effect.send(.setNavigation(.detail(gid))))
                return .merge(effects)

            case .onPostCommentAppear:
                return Effect.publisher {
                    Effect.send(.setPostCommentFocused(true))
                        .delay(for: .milliseconds(750), scheduler: DispatchQueue.main)
                }

            case .onAppear:
                if state.detailState == nil {
                    state.detailState = .init()
                }
                return state.scrollCommentID != nil ? Effect.send(.performScrollOpacityEffect) : .none

            case .updateReadingProgress(let gid, let progress):
                guard !gid.isEmpty else { return .none }
                return databaseClient
                    .updateReadingProgress(gid: gid, progress: progress).fireAndForget()

            case .teardown:
                return .cancel(ids: CancelID.allCases)

            case .postComment(let galleryURL, let commentID):
                guard !state.commentContent.isEmpty else { return .none }
                if let commentID = commentID {
                    return EditGalleryCommentRequest(
                        commentID: commentID, content: state.commentContent, galleryURL: galleryURL
                    )
                    .effect.map(Action.performCommentActionDone).cancellable(id: CancelID.postComment)
                } else {
                    return CommentGalleryRequest(content: state.commentContent, galleryURL: galleryURL)
                        .effect.map(Action.performCommentActionDone).cancellable(id: CancelID.postComment)
                }

            case .voteComment(let gid, let token, let apiKey, let commentID, let vote):
                guard let gid = Int(gid), let commentID = Int(commentID),
                      let apiuid = Int(cookieClient.apiuid)
                else { return .none }
                return VoteGalleryCommentRequest(
                    apiuid: apiuid, apikey: apiKey, gid: gid, token: token,
                    commentID: commentID, commentVote: vote
                )
                .effect.map(Action.performCommentActionDone).cancellable(id: CancelID.voteComment)

            case .performCommentActionDone:
                return .none

            case .fetchGallery(let url, let isGalleryImageURL):
                state.route = .hud
                return GalleryReverseRequest(url: url, isGalleryImageURL: isGalleryImageURL)
                    .effect.map({ Action.fetchGalleryDone(url, $0) }).cancellable(id: CancelID.fetchGallery)

            case .fetchGalleryDone(let url, let result):
                state.route = nil
                switch result {
                case .success(let gallery):
                    return .merge(
                        databaseClient.cacheGalleries([gallery]).fireAndForget(),
                        Effect.send(.handleGalleryLink(url))
                    )
                case .failure:
                    return Effect.publisher {
                        Effect.send(.setHUDConfig(.error))
                            .delay(for: .milliseconds(500), scheduler: DispatchQueue.main)
                    }
                }

            case .detail:
                return .none
            }
        }
        .haptics(
            unwrapping: \.route,
            case: /Route.postComment,
            hapticsClient: hapticsClient
        )
    }
}
