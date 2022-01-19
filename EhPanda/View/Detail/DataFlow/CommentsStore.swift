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
        case detail(String)
        case postComment(String)
    }

    static func == (lhs: CommentsState, rhs: CommentsState) -> Bool {
        lhs.route == rhs.route
        && lhs.commentContent == rhs.commentContent
        && lhs.draftCommentFocused == rhs.draftCommentFocused
        && lhs.hudConfig == rhs.hudConfig
        && lhs.scrollCommentID == rhs.scrollCommentID
        && lhs.scrollRowOpacity == rhs.scrollRowOpacity
        && lhs.detailStates == rhs.detailStates
        && (lhs.detailReducer == nil) == (rhs.detailReducer == nil)
    }

    @BindableState var route: Route?
    @BindableState var commentContent = ""
    @BindableState var draftCommentFocused = false

    var hudConfig: TTProgressHUDConfig = .loading
    var scrollCommentID: String?
    var scrollRowOpacity: Double = 1

    var detailStates = IdentifiedArrayOf<DetailState>()
    var detailReducer: Reducer<DetailState, DetailAction, DetailEnvironment>?
}

enum CommentsAction: BindableAction {
    case binding(BindingAction<CommentsState>)
    case setNavigation(CommentsState.Route?)
    case setDetailState(DetailState)
    case clearSubStates

    case setHUDConfig(TTProgressHUDConfig)
    case setDraftCommentFocused(Bool)
    case setScrollRowOpacity(Double)
    case setCommentContent(String)
    case performScrollOpacityEffect
    case handleCommentLink(URL)
    case handleDeepLink(URL)
    case onDraftCommentAppear
    case onAppear

    case updateReadingProgress(String, Int)

    case postComment(String, String? = nil)
    case voteComment(String, String, String, String, Int)
    case performCommentActionDone(Result<Any, AppError>)
    case fetchGallery(URL, Bool)
    case fetchGalleryDone(URL, Result<Gallery, AppError>)

    indirect case detail(id: String, action: DetailAction)
}

struct CommentsEnvironment {
    let urlClient: URLClient
    let fileClient: FileClient
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
    let clipboardClient: ClipboardClient
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

    case .setDetailState(let detailState):
        state.detailStates = [detailState]
        return .none

    case .clearSubStates:
        state.detailStates = .init()
        state.commentContent = .init()
        state.draftCommentFocused = false
        return .none

    case .setHUDConfig(let config):
        state.hudConfig = config
        return .none

    case .setDraftCommentFocused(let isFocused):
        state.draftCommentFocused = isFocused
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
                .delay(for: .milliseconds(1250), scheduler: DispatchQueue.main).eraseToEffect()
        )

    case .handleCommentLink(let url):
        guard environment.urlClient.checkIfHandleable(url) else {
            return environment.uiApplicationClient.openURL(url).fireAndForget()
        }
        let (isGalleryImageURL, _, _) = environment.urlClient.analyzeURL(url)
        let gid = environment.urlClient.parseGalleryID(url)
        guard !environment.databaseClient.checkGalleryExistence(gid: gid) else {
            return .init(value: .handleDeepLink(url))
        }
        return .init(value: .fetchGallery(url, isGalleryImageURL))

    case .handleDeepLink(let url):
        let (_, pageIndex, commentID) = environment.urlClient.analyzeURL(url)
        let gid = environment.urlClient.parseGalleryID(url)
        var effects = [Effect<CommentsAction, Never>]()
        if let pageIndex = pageIndex {
            effects.append(.init(value: .setDetailState(.init(id: gid))))
            effects.append(.init(value: .updateReadingProgress(gid, pageIndex)))
            effects.append(
                .init(value: .detail(id: gid, action: .setNavigation(.reading)))
                    .delay(for: .milliseconds(750), scheduler: DispatchQueue.main).eraseToEffect()
            )
        } else if let commentID = commentID {
            var detailState = DetailState(id: gid)
            detailState.commentsState.scrollCommentID = commentID
            effects.append(.init(value: .setDetailState(detailState)))
            effects.append(
                .init(value: .detail(id: gid, action: .setNavigation(.comments)))
                    .delay(for: .milliseconds(750), scheduler: DispatchQueue.main).eraseToEffect()
            )
        } else {
            effects.append(.init(value: .setDetailState(.init(id: gid))))
        }
        effects.append(.init(value: .setNavigation(.detail(gid))))
        return .merge(effects)

    case .onDraftCommentAppear:
        return .init(value: .setDraftCommentFocused(true))
            .delay(for: .milliseconds(750), scheduler: DispatchQueue.main).eraseToEffect()

    case .onAppear:
        state.detailReducer = anyDetailReducer
        return state.scrollCommentID != nil ? .init(value: .performScrollOpacityEffect) : .none

    case .updateReadingProgress(let gid, let progress):
        guard !gid.isEmpty else { return .none }
        return environment.databaseClient
            .updateReadingProgress(gid: gid, progress: progress).fireAndForget()

    case .postComment(let galleryURL, let commentID):
        guard !state.commentContent.isEmpty else { return .none }
        if let commentID = commentID {
            return EditGalleryCommentRequest(
                commentID: commentID, content: state.commentContent, galleryURL: galleryURL
            )
            .effect.map(CommentsAction.performCommentActionDone)
        } else {
            return CommentGalleryRequest(content: state.commentContent, galleryURL: galleryURL)
                .effect.map(CommentsAction.performCommentActionDone)
        }

    case .voteComment(let gid, let token, let apiKey, let commentID, let vote):
        guard let gid = Int(gid), let commentID = Int(commentID),
              let apiuid = Int(environment.cookiesClient.apiuid)
        else { return .none }
        return VoteGalleryCommentRequest(
            apiuid: apiuid, apikey: apiKey, gid: gid, token: token,
            commentID: commentID, commentVote: vote
        )
        .effect.map(CommentsAction.performCommentActionDone)

    case .performCommentActionDone:
        return .none

    case .fetchGallery(let url, let isGalleryImageURL):
        state.route = .hud
        return GalleryReverseRequest(url: url, isGalleryImageURL: isGalleryImageURL)
            .effect.map({ CommentsAction.fetchGalleryDone(url, $0) })

    case .fetchGalleryDone(let url, let result):
        state.route = nil
        switch result {
        case .success(let gallery):
            return .merge(
                environment.databaseClient.cacheGalleries([gallery]).fireAndForget(),
                .init(value: .handleDeepLink(url))
            )
        case .failure:
            return .init(value: .setHUDConfig(.error))
                .delay(for: .milliseconds(500), scheduler: DispatchQueue.main).eraseToEffect()
        }

    case .detail:
        guard let detailReducer = state.detailReducer else { return .none }
        return detailReducer.forEach(
            state: \CommentsState.detailStates,
            action: /CommentsAction.detail(id:action:),
            environment: { (environment: CommentsEnvironment) in
                .init(
                    urlClient: environment.urlClient,
                    fileClient: environment.fileClient,
                    hapticClient: environment.hapticClient,
                    cookiesClient: environment.cookiesClient,
                    databaseClient: environment.databaseClient,
                    clipboardClient: environment.clipboardClient,
                    uiApplicationClient: environment.uiApplicationClient
                )
            }
        )
        .run(&state, action, environment)
    }
}
.binding()
