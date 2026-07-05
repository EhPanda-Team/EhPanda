import AppTools
import SwiftUI
import AppModels
import Sharing
import ComposableArchitecture
import URLClient
import UserDefaultsClient
import HapticsClient
import DatabaseClient
import NetworkingFeature
import ClipboardClient
import AppComponents
import DetailFeature

@Reducer
struct AppRouteReducer {
    @Reducer
    enum Destination {
        @ReducerCaseIgnored
        case setting(EquatableVoid)
        @ReducerCaseIgnored
        case newDawn(Greeting)
    }

    @ObservableState
    struct State: Equatable {
        @Presents var toast: AppAlertState<Never>?
        // The deep-link/clipboard gallery, presented modally as the root of its own gallery stack.
        @Presents var detail: DetailReducer.State?
        var path = StackState<GalleryPath.State>()
        @Presents var destination: Destination.State?

        init() {}
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case toast(PresentationAction<Never>)
        case destination(PresentationAction<Destination.Action>)
        case detail(PresentationAction<DetailReducer.Action>)
        case path(StackActionOf<GalleryPath>)
        case presentSetting
        case presentNewDawn(Greeting)
        case presentGalleryDetail(String, DownloadedGallery?)
        case setToast(AppAlertState<Never>)

        case detectClipboardURL
        case handleDeepLink(URL)
        case handleGalleryLink(URL)

        case updateReadingProgress(String, Int)

        case fetchGallery(URL, Bool)
        case fetchGalleryDone(URL, Result<Gallery, AppError>)
        case fetchGreetingDone(Result<Greeting, AppError>)
    }

    @Dependency(\.userDefaultsClient) private var userDefaultsClient
    @Dependency(\.clipboardClient) private var clipboardClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.urlClient) private var urlClient
    @Dependency(\.date) private var date

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .toast:
                return .none

            case .destination:
                return .none

            case .detail(.dismiss):
                state.path.removeAll()
                return .none

            case let .detail(.presented(.delegate(delegate))):
                if let next = GalleryNavigation.nextScreen(for: .detail(.delegate(delegate))) {
                    state.path.appendGuardingDuplicate(next)
                }
                return .none

            case .detail:
                return .none

            case let .path(.element(id: _, action: .comments(.delegate(.performedCommentAction(gid))))):
                if state.detail?.gid == gid {
                    return .send(.detail(.presented(.fetchGalleryDetail)))
                }
                guard let id = state.path.detailID(forGID: gid) else { return .none }
                return .send(.path(.element(id: id, action: .detail(.fetchGalleryDetail))))

            case let .path(.element(id: _, action: elementAction)):
                if let next = GalleryNavigation.nextScreen(for: elementAction) {
                    state.path.appendGuardingDuplicate(next)
                }
                return .none

            case .path:
                return .none

            case .presentSetting:
                state.destination = .setting(.init())
                return .none

            case .presentNewDawn(let greeting):
                state.destination = .newDawn(greeting)
                return .none

            case .presentGalleryDetail(let gid, let download):
                // A gallery opened from a tab on iPad: modal detail rooting its own gallery stack,
                // seeded from the local download when one exists so it renders offline.
                state.path.removeAll()
                state.detail = .init(gid: gid, seededFrom: download)
                return .none

            case .setToast(let config):
                state.toast = config
                return .none

            case .detectClipboardURL:
                let currentChangeCount = clipboardClient.changeCount()
                guard currentChangeCount != userDefaultsClient
                        .getValue(.clipboardChangeCount) else { return .none }
                var effects: [Effect<Action>] = [
                    .run(operation: { _ in userDefaultsClient.setValue(currentChangeCount, .clipboardChangeCount) })
                ]
                if let url = clipboardClient.url() {
                    effects.append(.send(.handleDeepLink(url)))
                }
                return .merge(effects)

            case .handleDeepLink(let url):
                let url = urlClient.resolveAppSchemeURL(url) ?? url
                guard urlClient.checkIfHandleable(url) else { return .none }
                var delay = 0
                if state.detail != nil {
                    delay = 1000
                    state.detail = nil
                    state.path.removeAll()
                }
                let analysis = urlClient.analyzeURL(url)
                let gid = urlClient.parseGalleryID(url)
                guard databaseClient.fetchGallery(gid: gid) == nil else {
                    return .run { [delay] send in
                        try await Task.sleep(for: .milliseconds(delay + 250))
                        await send(.handleGalleryLink(url))
                    }
                }
                return .run { [delay] send in
                    try await Task.sleep(for: .milliseconds(delay))
                    await send(.fetchGallery(url, analysis.isGalleryImageURL))
                }

            case .handleGalleryLink(let url):
                let analysis = urlClient.analyzeURL(url)
                let pageIndex = analysis.pageIndex
                let commentID = analysis.commentID
                let gid = urlClient.parseGalleryID(url)
                var deepLink: GalleryDeepLink?
                var effects = [Effect<Action>]()
                if let pageIndex = pageIndex {
                    effects.append(.send(.updateReadingProgress(gid, pageIndex)))
                    deepLink = .reading(page: pageIndex)
                } else if let commentID = commentID {
                    deepLink = .comments(commentID: commentID)
                }
                state.path.removeAll()
                state.detail = DetailReducer.State(gid: gid, pendingDeepLink: deepLink)
                effects.append(.run(operation: { _ in await hapticsClient.generateFeedback(.light) }))
                return .merge(effects)

            case .updateReadingProgress(let gid, let progress):
                guard !gid.isEmpty else { return .none }
                // Deep link straight to a page: the token isn't known here, so the entry is created
                // tokenless and backfilled when the detail screen records the open.
                @Shared(.galleryHistory) var galleryHistory
                $galleryHistory.withLock {
                    $0.updateReadingProgress(gid: gid, token: "", progress: progress, date: date.now)
                }
                return .none

            case .fetchGallery(let url, let isGalleryImageURL):
                state.toast = .loading()
                return .run { send in
                    let response = await GalleryReverseRequest(
                        url: url, isGalleryImageURL: isGalleryImageURL
                    )
                    .response()
                    await send(.fetchGalleryDone(url, response))
                }

            case .fetchGalleryDone(let url, let result):
                state.toast = nil
                switch result {
                case .success(let gallery):
                    return .run { send in
                        await databaseClient.cacheGalleries([gallery])
                        await send(.handleGalleryLink(url))
                    }
                case .failure:
                    // Let the loading toast animate out before showing the error toast.
                    return .run { send in
                        try await Task.sleep(for: .milliseconds(500))
                        await send(.setToast(.error()))
                    }
                }

            case .fetchGreetingDone(let result):
                if case .success(let greeting) = result, !greeting.gainedNothing {
                    return .send(.presentNewDawn(greeting))
                }
                return .none
            }
        }
        .haptics(
            unwrapping: \.destination,
            case: \.newDawn,
            hapticsClient: hapticsClient
        )
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$detail, action: \.detail) { DetailReducer() }
        .ifLet(\.$toast, action: \.toast)
        .forEach(\.path, action: \.path)
    }
}

extension AppRouteReducer.Destination.State: Equatable, Sendable {}
extension AppRouteReducer.Destination.Action: Equatable, Sendable {}
