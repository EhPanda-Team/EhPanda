//
//  CommentsStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/16.
//

import TTProgressHUD
import ComposableArchitecture

struct CommentsState: Equatable {
    enum Route: Equatable {
        case hud
        case postComment(String)
    }
    struct CancelID: Hashable {
        let id = String(describing: CommentsState.self)
    }

    @BindableState var route: Route?
    @BindableState var commentContent = ""
    @BindableState var postCommentFocused = false

    var hudConfig: TTProgressHUDConfig = .loading
    var scrollCommentID: String?
    var scrollRowOpacity: Double = 1
}

enum CommentsAction: BindableAction {
    case binding(BindingAction<CommentsState>)
    case setNavigation(CommentsState.Route?)
    case clearSubStates
    case clearScrollCommentID

    case setHUDConfig(TTProgressHUDConfig)
    case setPostCommentFocused(Bool)
    case setScrollRowOpacity(Double)
    case setCommentContent(String)
    case performScrollOpacityEffect
    case handleCommentLink(URL)
    case onPostCommentAppear
    case onAppear

    case updateReadingProgress(String, Int)

    case teardown
    case postComment(URL, String? = nil)
    case voteComment(String, String, String, String, Int)
    case performCommentActionDone(Result<Any, AppError>)
}

struct CommentsEnvironment {
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

var anyDetailReducer: Reducer<DetailState, DetailAction, DetailEnvironment> {
    detailReducer
}
let commentsReducer = Reducer<CommentsState, CommentsAction, CommentsEnvironment> { state, action, environment in
    switch action {
    case .binding(\.$route):
        return state.route == nil ? .init(value: .clearSubStates) : .none

    case .binding:
        return .none

    case .setNavigation(let route):
        state.route = route
        return route == nil ? .init(value: .clearSubStates) : .none

    case .clearSubStates:
        state.commentContent = .init()
        state.postCommentFocused = false
        return .none

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
            .init(value: .setScrollRowOpacity(0.25))
                .delay(for: .milliseconds(750), scheduler: DispatchQueue.main).eraseToEffect(),
            .init(value: .setScrollRowOpacity(1))
                .delay(for: .milliseconds(1250), scheduler: DispatchQueue.main).eraseToEffect(),
            .init(value: .clearScrollCommentID)
                .delay(for: .milliseconds(2000), scheduler: DispatchQueue.main).eraseToEffect()
        )

    case .handleCommentLink:
        return .none

    case .onPostCommentAppear:
        return .init(value: .setPostCommentFocused(true))
            .delay(for: .milliseconds(750), scheduler: DispatchQueue.main).eraseToEffect()

    case .onAppear:
        return state.scrollCommentID != nil ? .init(value: .performScrollOpacityEffect) : .none

    case .updateReadingProgress(let gid, let progress):
        guard !gid.isEmpty else { return .none }
        return environment.databaseClient
            .updateReadingProgress(gid: gid, progress: progress).fireAndForget()

    case .teardown:
        return .cancel(id: CommentsState.CancelID())

    case .postComment(let galleryURL, let commentID):
        guard !state.commentContent.isEmpty else { return .none }
        if let commentID = commentID {
            return EditGalleryCommentRequest(
                commentID: commentID, content: state.commentContent, galleryURL: galleryURL
            )
            .effect.map(CommentsAction.performCommentActionDone).cancellable(id: CommentsState.CancelID())
        } else {
            return CommentGalleryRequest(content: state.commentContent, galleryURL: galleryURL)
                .effect.map(CommentsAction.performCommentActionDone).cancellable(id: CommentsState.CancelID())
        }

    case .voteComment(let gid, let token, let apiKey, let commentID, let vote):
        guard let gid = Int(gid), let commentID = Int(commentID),
              let apiuid = Int(environment.cookiesClient.apiuid)
        else { return .none }
        return VoteGalleryCommentRequest(
            apiuid: apiuid, apikey: apiKey, gid: gid, token: token,
            commentID: commentID, commentVote: vote
        )
        .effect.map(CommentsAction.performCommentActionDone).cancellable(id: CommentsState.CancelID())

    case .performCommentActionDone:
        return .none
    }
}
.haptics(
    unwrapping: \.route,
    case: /CommentsState.Route.postComment,
    hapticClient: \.hapticClient
)
.binding()
