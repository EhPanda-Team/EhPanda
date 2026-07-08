import AppTools
import SwiftUI
import AppModels
import Sharing
import ComposableArchitecture
import URLClient
import UserDefaultsClient
import HapticsClient
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
        case presentGalleryDetail(Gallery, DownloadedGallery?)
        case setToast(AppAlertState<Never>)

        case detectClipboardURL
        case handleDeepLink(URL)
        case handleGalleryLink(URL, Gallery)

        case updateReadingProgress(gid: String, token: String, progress: Int)

        case fetchGallery(URL, Bool)
        case fetchGalleryDone(URL, Result<Gallery, AppError>)
        case fetchGreetingDone(Result<Greeting, AppError>)
    }

    @Dependency(\.userDefaultsClient) private var userDefaultsClient
    @Dependency(\.clipboardClient) private var clipboardClient
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

            case .presentGalleryDetail(let gallery, let download):
                // A gallery opened from a tab on iPad: modal detail rooting its own gallery stack,
                // seeded from the local download when one exists so it renders offline, otherwise
                // from the tapped gallery.
                state.path.removeAll()
                if let download {
                    state.detail = .init(seededFrom: download)
                } else {
                    state.detail = .init(gallery: gallery)
                }
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
                // Always fetch the gallery so the pushed detail is seeded from it.
                let analysis = urlClient.analyzeURL(url)
                return .run { [delay] send in
                    try await Task.sleep(for: .milliseconds(delay))
                    await send(.fetchGallery(url, analysis.isGalleryImageURL))
                }

            case .handleGalleryLink(let url, let gallery):
                let analysis = urlClient.analyzeURL(url)
                let deepLink = GalleryDeepLink(pageIndex: analysis.pageIndex, commentID: analysis.commentID)
                var effects = [Effect<Action>]()
                if let pageIndex = analysis.pageIndex {
                    effects.append(.send(.updateReadingProgress(
                        gid: gallery.id, token: gallery.token, progress: pageIndex
                    )))
                }
                state.path.removeAll()
                state.detail = DetailReducer.State(gallery: gallery, pendingDeepLink: deepLink)
                effects.append(.run(operation: { _ in await hapticsClient.generateFeedback(.light) }))
                return .merge(effects)

            case let .updateReadingProgress(gid, token, progress):
                // The linked gallery is in scope, so persist the real token — the entry resolves
                // immediately rather than waiting for the detail screen to backfill it. Invalid
                // gid/token records are rejected inside the shared mutator.
                @Shared(.galleryHistory) var galleryHistory
                $galleryHistory.withLock {
                    $0.updateReadingProgress(gid: gid, token: token, progress: progress, date: date.now)
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
                    return .send(.handleGalleryLink(url, gallery))
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
