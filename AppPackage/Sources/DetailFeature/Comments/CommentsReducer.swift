import Foundation
import AppModels
import Sharing
import ComposableArchitecture
import URLClient
import ApplicationClient
import HapticsClient
import NetworkingFeature
import CookieClient
import AppComponents

@Reducer
public struct CommentsReducer: Sendable {
    @Reducer
    public enum Destination {
        @ReducerCaseIgnored
        case postComment(String)
    }

    public enum Delegate: Equatable, Sendable {
        // Open the linked gallery (optionally deep-linking to a page or comment) as a new stack element.
        case pushDetail(Gallery, GalleryDeepLink?)
        // A comment was voted/edited; ask the host to refresh the detail with this gid so it stays in sync.
        case performedCommentAction(String)
    }

    private enum CancelID {
        case postComment, voteComment, fetchGallery
    }

    @ObservableState
    public struct State: Equatable {
        @Presents public var toast: AppAlertState<Never>?
        @Presents public var destination: Destination.State?
        public var commentContent = ""
        public var postCommentFocused = false
        public var scrollCommentID: String?
        public var scrollRowOpacity: Double = 1

        // Display data captured when this screen is pushed onto the host's gallery stack.
        public var gid = ""
        public var token = ""
        public var apiKey = ""
        public var galleryURL: URL
        public var comments = [GalleryComment]()

        public init(
            gid: String = "", token: String = "", apiKey: String = "",
            galleryURL: URL, comments: [GalleryComment] = [], scrollCommentID: String? = nil
        ) {
            self.gid = gid
            self.token = token
            self.apiKey = apiKey
            self.galleryURL = galleryURL
            self.comments = comments
            self.scrollCommentID = scrollCommentID
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case toast(PresentationAction<Never>)
        case destination(PresentationAction<Destination.Action>)
        case presentPostComment(commentID: String, content: String? = nil)
        case clearScrollCommentID
        case delegate(Delegate)

        case setToast(AppAlertState<Never>)
        case setPostCommentFocused(Bool)
        case setScrollRowOpacity(Double)
        case performScrollOpacityEffect
        case handleCommentLink(URL)
        case handleGalleryLink(URL, Gallery)
        case onPostCommentAppear
        case onAppear

        case updateReadingProgress(gid: String, token: String, progress: Int)

        case postComment(URL, String? = nil)
        case voteComment(String, String, String, String, Int)
        case performCommentActionDone(Result<Void, AppError>)
        case fetchGallery(URL, Bool)
        case fetchGalleryDone(URL, Result<Gallery, AppError>)
    }

    @Dependency(\.applicationClient) private var applicationClient
    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.cookieClient) private var cookieClient
    @Dependency(\.urlClient) private var urlClient
    @Dependency(\.date) private var date

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .toast:
                return .none

            case .destination:
                return .none

            case let .presentPostComment(commentID, content):
                // Reset on present (not on dismiss): the sheet is a raw case binding, so an
                // interactive swipe-down never sends `.destination(.dismiss)`. Editing passes the
                // comment's text as `content`; the new-comment button passes nil to clear it.
                state.commentContent = content ?? ""
                state.postCommentFocused = false
                state.destination = .postComment(commentID)
                return .none

            case .clearScrollCommentID:
                state.scrollCommentID = nil
                return .none

            case .delegate:
                return .none

            case .setToast(let config):
                state.toast = config
                return .none

            case .setPostCommentFocused(let isFocused):
                state.postCommentFocused = isFocused
                return .none

            case .setScrollRowOpacity(let opacity):
                state.scrollRowOpacity = opacity
                return .none

            case .performScrollOpacityEffect:
                return .merge(
                    .run { send in
                        try await Task.sleep(for: .milliseconds(750))
                        await send(.setScrollRowOpacity(0.25))
                    },
                    .run { send in
                        try await Task.sleep(for: .milliseconds(1250))
                        await send(.setScrollRowOpacity(1))
                    },
                    .run { send in
                        try await Task.sleep(for: .milliseconds(2000))
                        await send(.clearScrollCommentID)
                    }
                )

            case .handleCommentLink(let url):
                guard urlClient.checkIfHandleable(url) else {
                    return .run(operation: { _ in await applicationClient.openURL(url) })
                }
                // Always fetch the linked gallery so the pushed detail is seeded from it (no cache).
                let analysis = urlClient.analyzeURL(url)
                return .send(.fetchGallery(url, analysis.isGalleryImageURL))

            case .handleGalleryLink(let url, let gallery):
                let analysis = urlClient.analyzeURL(url)
                let deepLink = GalleryDeepLink(pageIndex: analysis.pageIndex, commentID: analysis.commentID)
                var effects = [Effect<Action>]()
                if let pageIndex = analysis.pageIndex {
                    effects.append(.send(.updateReadingProgress(
                        gid: gallery.id, token: gallery.token, progress: pageIndex
                    )))
                }
                effects.append(.send(.delegate(.pushDetail(gallery, deepLink))))
                return .merge(effects)

            case .onPostCommentAppear:
                return .run { send in
                    try await Task.sleep(for: .milliseconds(750))
                    await send(.setPostCommentFocused(true))
                }

            case .onAppear:
                return state.scrollCommentID != nil ? .send(.performScrollOpacityEffect) : .none

            case let .updateReadingProgress(gid, token, progress):
                // The linked gallery is in scope, so persist the real token — the entry resolves
                // immediately rather than waiting for the detail screen to backfill it. Invalid
                // gid/token records are rejected inside the shared mutator.
                @Shared(.galleryHistory) var galleryHistory
                $galleryHistory.withLock {
                    $0.updateReadingProgress(gid: gid, token: token, progress: progress, date: date.now)
                }
                return .none

            case .postComment(let galleryURL, let commentID):
                guard !state.commentContent.isEmpty else { return .none }
                if let commentID = commentID {
                    return .run { [commentContent = state.commentContent] send in
                        let response = await EditGalleryCommentRequest(
                            commentID: commentID,
                            content: commentContent,
                            galleryURL: galleryURL
                        )
                        .response()
                        await send(.performCommentActionDone(response))
                    }
                    .cancellable(id: CancelID.postComment)
                } else {
                    return .run { [commentContent = state.commentContent] send in
                        let response = await CommentGalleryRequest(
                            content: commentContent, galleryURL: galleryURL
                        )
                        .response()
                        await send(.performCommentActionDone(response))
                    }
                    .cancellable(id: CancelID.postComment)
                }

            case .voteComment(let gid, let token, let apiKey, let commentID, let vote):
                guard let gid = Int(gid), let commentID = Int(commentID),
                      let apiuid = Int(cookieClient.apiuid)
                else { return .none }
                return .run {  send in
                    let response = await VoteGalleryCommentRequest(
                        apiuid: apiuid,
                        apikey: apiKey,
                        gid: gid,
                        token: token,
                        commentID: commentID,
                        commentVote: vote
                    )
                    .response()
                    await send(.performCommentActionDone(response))
                }
                .cancellable(id: CancelID.voteComment)

            case .performCommentActionDone(let result):
                switch result {
                case .success:
                    return .merge(
                        .send(.delegate(.performedCommentAction(state.gid))),
                        .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.success) })
                    )
                case .failure:
                    return .run(operation: { _ in await hapticsClient.generateNotificationFeedback(.error) })
                }

            case .fetchGallery(let url, let isGalleryImageURL):
                state.toast = .loading()
                return .run {  send in
                    let response = await GalleryReverseRequest(
                        url: url, isGalleryImageURL: isGalleryImageURL
                    )
                    .response()
                    await send(.fetchGalleryDone(url, response))
                }
                .cancellable(id: CancelID.fetchGallery)

            case .fetchGalleryDone(let url, let result):
                state.toast = nil
                switch result {
                case .success(let gallery):
                    return .send(.handleGalleryLink(url, gallery))
                case .failure:
                    // Let the loading toast animate out before showing the error toast.
                    return .run { send in
                        try await Task.sleep(for: .milliseconds(500))
                        await send(.setToast(.error()))
                    }
                }
            }
        }
        .haptics(
            unwrapping: \.destination,
            case: \.postComment,
            hapticsClient: hapticsClient
        )
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$toast, action: \.toast)
    }
}

extension CommentsReducer.Destination.State: Equatable, Sendable {}
