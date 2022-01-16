//
//  CommentsStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/16.
//

import TTProgressHUD
import ComposableArchitecture

struct CommentsState: Equatable {
    static func == (lhs: CommentsState, rhs: CommentsState) -> Bool {
        lhs.route == rhs.route
        && lhs.hudConfig == rhs.hudConfig
        && lhs.scrollGalleryID == rhs.scrollGalleryID
        && lhs.scrollRowOpacity == rhs.scrollRowOpacity
        && lhs.detailStates == rhs.detailStates
        && (lhs.detailReducer == nil) == (rhs.detailReducer == nil)
    }

    enum Route: Equatable {
        case hud
        case detail(String)
        case postComment(String)
    }

    @BindableState var route: Route?
    var hudConfig: TTProgressHUDConfig = .loading
    var scrollGalleryID: String?
    var scrollRowOpacity: Double = 1

    var detailStates = IdentifiedArrayOf<DetailState>()
    var detailReducer: Reducer<DetailState, DetailAction, DetailEnvironment>?
}

enum CommentsAction: BindableAction {
    case binding(BindingAction<CommentsState>)
    case setNavigation(CommentsState.Route?)
    case initializeRecursiveStates(String)
    case setHUDConfig(TTProgressHUDConfig)
    case performScrollOpacityEffect
    case setScrollRowOpacity(Double)
    case handleCommentLink(URL)
    case onAppear

    case voteComment(String, String, String, String, Int)
    case voteCommentDone(Result<Any, AppError>)
    case fetchGallery(URL, Bool)
    case fetchGalleryDone(Result<Gallery, AppError>)

    indirect case detail(id: String, action: DetailAction)
}

struct CommentsEnvironment {
    let urlClient: URLClient
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
    let uiApplicationClient: UIApplicationClient
}

var anyDetailReducer: Reducer<DetailState, DetailAction, DetailEnvironment> {
    detailReducer
}
let commentsReducer = Reducer<CommentsState, CommentsAction, CommentsEnvironment>.combine(
    .init { state, action, environment in
        switch action {
        case .binding:
            return .none

        case .setNavigation(let route):
            state.route = route
            return .none

        case .initializeRecursiveStates(let gid):
            state.detailReducer = anyDetailReducer
            state.detailStates = .init(uniqueElements: [.init(id: gid)])
            return .none

        case .setHUDConfig(let config):
            state.hudConfig = config
            return .none

        case .performScrollOpacityEffect:
            return .merge(
                .init(value: .setScrollRowOpacity(0.25))
                    .delay(for: .milliseconds(750), scheduler: DispatchQueue.main).eraseToEffect(),
                .init(value: .setScrollRowOpacity(1))
                    .delay(for: .milliseconds(1250), scheduler: DispatchQueue.main).eraseToEffect()
            )

        case .setScrollRowOpacity(let opacity):
            state.scrollRowOpacity = opacity
            return .none

        case .handleCommentLink(let url):
            guard environment.urlClient.checkIfHandleable(url) else {
                return environment.uiApplicationClient.openURL(url).fireAndForget()
            }
            let (isGalleryImageURL, pageIndex, commentID) = environment.urlClient.analyzeURL(url)
            let gid = environment.urlClient.parseGalleryID(url)
            guard !environment.databaseClient.checkGalleryExistence(gid: gid) else {
                return .merge(
                    .init(value: .initializeRecursiveStates(gid)),
                    .init(value: .setNavigation(.detail(gid)))
                )
            }
            return .init(value: .fetchGallery(url, isGalleryImageURL))

        case .onAppear:
            return state.scrollGalleryID != nil ? .init(value: .performScrollOpacityEffect) : .none

        case .voteComment(let gid, let token, let apiKey, let commentID, let vote):
            guard let gid = Int(gid), let commentID = Int(commentID),
                  let apiuid = Int(environment.cookiesClient.apiuid)
            else { return .none }
            return VoteGalleryCommentRequest(
                apiuid: apiuid, apikey: apiKey, gid: gid, token: token,
                commentID: commentID, commentVote: vote
            )
            .effect.map(CommentsAction.voteCommentDone)

        case .voteCommentDone:
            return .none

        case .fetchGallery(let url, let isGalleryImageURL):
            state.route = .hud
            return GalleryReverseRequest(url: url, isGalleryImageURL: isGalleryImageURL)
                .effect.map(CommentsAction.fetchGalleryDone)

        case .fetchGalleryDone(let result):
            state.route = nil
            switch result {
            case .success(let gallery):
                return .merge(
                    environment.databaseClient.cacheGalleries([gallery]).fireAndForget(),
                    .init(value: .initializeRecursiveStates(gallery.id)),
                    .init(value: .setNavigation(.detail(gallery.id)))
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
                        hapticClient: environment.hapticClient,
                        cookiesClient: environment.cookiesClient,
                        databaseClient: environment.databaseClient,
                        uiApplicationClient: environment.uiApplicationClient
                    )
                }
            )
            .run(&state, action, environment)
        }
    }
    .binding()
)
