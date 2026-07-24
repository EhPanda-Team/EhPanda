import AnalyticsClient
import AppComponents
import AppModels
import AppTools
import ClipboardClient
import ComposableArchitecture
import DetailFeature
import HapticsClient
import NetworkingFeature
import Sharing
import SwiftUI
import UserDefaultsClient

@Reducer
struct PresentationFeature {
    private enum CancelID {
        case fetchGallery
    }

    @Reducer
    enum Destination {
        @ReducerCaseIgnored
        case errorInfo(ErrorInfo)
        @ReducerCaseIgnored
        case setting(EquatableVoid)
        @ReducerCaseIgnored
        case newDawn(Greeting)
    }

    struct PendingGalleryLink: Equatable, Sendable {
        let url: URL
        let gallery: Gallery
    }

    @ObservableState
    struct State: Equatable {
        @Presents var toast: AppAlertState<Never>?
        // The deep-link/clipboard gallery, presented modally as the root of its own gallery stack.
        @Presents var detail: DetailReducer.State?
        var path = StackState<GalleryPath.State>()
        @Presents var destination: Destination.State?
        var isAwaitingDetailDismissal = false
        var pendingGalleryLink: PendingGalleryLink?

        init() {}
    }

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case toast(PresentationAction<Never>)
        case destination(PresentationAction<Destination.Action>)
        case detail(PresentationAction<DetailReducer.Action>)
        case path(StackActionOf<GalleryPath>)
        case presentErrorInfo(ErrorInfo)
        case presentSetting
        case presentNewDawn(Greeting)
        case presentGalleryDetail(gallery: Gallery, downloaded: DownloadedGallery?)
        case setToast(AppAlertState<Never>)

        case detectClipboardURL
        case detailDismissalCompleted
        case handleDeepLink(URL)
        case handleGalleryLink(url: URL, gallery: Gallery)

        case updateReadingProgress(gid: String, token: String, progress: Int)

        case fetchGallery(url: URL, isGalleryImageURL: Bool)
        case fetchGalleryDone(url: URL, result: Result<Gallery, AppError>)
        case fetchGreetingDone(Result<Greeting, AppError>)
    }

    @Dependency(\.userDefaultsClient) private var userDefaultsClient
    @Dependency(\.clipboardClient) private var clipboardClient
    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.analyticsClient) private var analyticsClient
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
                guard let next = GalleryNavigation.nextScreen(for: .detail(.delegate(delegate)))
                else { return .none }
                return GalleryNavigation.presentationEffect(
                    id: state.path.appendGuardingDuplicate(next),
                    screen: next,
                    embed: { .path(.element(id: $0, action: $1)) }
                )

            case .detail:
                return .none

            case let .path(.element(id: _, action: .comments(.delegate(.performedCommentAction(gid))))):
                if state.detail?.gid == gid {
                    return .send(.detail(.presented(.fetchGalleryDetail)))
                }
                guard let id = state.path.detailID(forGID: gid) else { return .none }
                return .send(.path(.element(id: id, action: .detail(.fetchGalleryDetail))))

            case let .path(.element(id: _, action: elementAction)):
                guard let next = GalleryNavigation.nextScreen(for: elementAction) else { return .none }
                return GalleryNavigation.presentationEffect(
                    id: state.path.appendGuardingDuplicate(next),
                    screen: next,
                    embed: { .path(.element(id: $0, action: $1)) }
                )

            case .path:
                return .none

            case .presentErrorInfo(let errorInfo):
                // Deliberately emits no analytics signal. This is the user drilling into a toast whose
                // error was already counted at `.setToast`; emitting here would double-count every error
                // a curious user inspects and skew the distribution toward errors with interesting
                // details. Do not add one here for symmetry with the other presentation cases (T-14-13).
                state.destination = .errorInfo(errorInfo)
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
                // Derive the analytics payload from the same source the detail is seeded from — the
                // download's gallery projection or the tapped gallery — so this fifth (modal) entry
                // path emits an identical `galleryDetailOpened` shape to the four push paths.
                let sourceGallery = download?.gallery ?? gallery
                if let download {
                    state.detail = .init(seededFrom: download)
                } else {
                    state.detail = .init(gallery: gallery)
                }
                // Presenting the modal is what starts its load — the reducer-side replacement for
                // the detail view's former `onAppear`.
                return .merge(
                    .send(.detail(.presented(.onPresented))),
                    // Payload is a closed `Category` plus exact per-namespace tag counts — no
                    // identifier, no title, no URL. `TagNamespaceCounts` and `Category` are the same
                    // audited, content-free reduction entry points the push paths use (D-06, D-09).
                    .run(operation: { _ in
                        analyticsClient.send(.galleryDetailOpened(
                            category: sourceGallery.category,
                            tagNamespaces: TagNamespaceCounts(tags: sourceGallery.tags)
                        ))
                    })
                )

            case .setToast(let config):
                state.toast = config
                // The centralized user-visible error surface (D-05 family 4). Only a toast carrying
                // diagnostics is a classifiable error worth counting; a caption-only toast has no
                // `AppError` and emits nothing. The payload is the `AppError` case alone, through
                // `AppErrorKind` — never `ErrorInfo`'s per-incident String diagnostics (D-06, D-09).
                guard let errorInfo = config.errorInfo else { return .none }
                return .run(operation: { _ in
                    analyticsClient.send(.errorSurfaced(AppErrorKind(errorInfo.error)))
                })

            case .detectClipboardURL:
                let currentChangeCount = clipboardClient.changeCount()
                guard currentChangeCount != userDefaultsClient
                        .getValue(.clipboardChangeCount) else { return .none }
                var effects: [Effect<Action>] = [
                    .run(operation: { _ in userDefaultsClient.setValue(currentChangeCount, .clipboardChangeCount) })
                ]
                if let url = clipboardClient.url(), GalleryURLParser.parse(url) != nil {
                    effects.append(.send(.handleDeepLink(url)))
                }
                return .merge(effects)

            case .detailDismissalCompleted:
                guard state.isAwaitingDetailDismissal else { return .none }
                state.isAwaitingDetailDismissal = false
                guard let pendingGalleryLink = state.pendingGalleryLink else { return .none }
                state.pendingGalleryLink = nil
                return .send(.handleGalleryLink(
                    url: pendingGalleryLink.url,
                    gallery: pendingGalleryLink.gallery
                ))

            case .handleDeepLink(let url):
                guard let route = GalleryURLParser.parse(url) else {
                    let errorInfo = ErrorInfo(
                        error: .unsupportedDeepLink,
                        context: .unsupportedLink(url: url)
                    )
                    state.toast = .error(errorInfo)
                    return .none
                }
                if state.detail != nil {
                    state.isAwaitingDetailDismissal = true
                    state.detail = nil
                    state.path.removeAll()
                }
                if state.isAwaitingDetailDismissal {
                    // A later deep link supersedes any fetched link still waiting for the same
                    // dismissal completion. Its in-flight fetch also replaces the previous one.
                    state.pendingGalleryLink = nil
                }
                // Always fetch the gallery so the pushed detail is seeded from it.
                return .send(.fetchGallery(url: route.url, isGalleryImageURL: route.isGalleryImageURL))

            case .handleGalleryLink(let url, let gallery):
                let route = GalleryURLParser.parse(url)
                let deepLink = GalleryDeepLink(pageIndex: route?.pageIndex, commentID: route?.commentID)
                var effects = [Effect<Action>]()
                if let pageIndex = route?.pageIndex {
                    effects.append(.send(.updateReadingProgress(
                        gid: gallery.id, token: gallery.token, progress: pageIndex
                    )))
                }
                state.path.removeAll()
                state.detail = DetailReducer.State(gallery: gallery, pendingDeepLink: deepLink)
                // The deep-link/clipboard entry constructs its detail here, so it carries the load
                // send too — the same presentation seam as the tap path, no view `onAppear`.
                effects.append(.send(.detail(.presented(.onPresented))))
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
                    do throws(AppError) {
                        let gallery = try await GalleryReverseRequest(
                            url: url,
                            isGalleryImageURL: isGalleryImageURL
                        )
                        .response()
                        await send(.fetchGalleryDone(url: url, result: .success(gallery)))
                    } catch {
                        guard Task.isCancelled == false else { return }
                        await send(.fetchGalleryDone(url: url, result: .failure(error)))
                    }
                }
                .cancellable(id: CancelID.fetchGallery, cancelInFlight: true)

            case .fetchGalleryDone(let url, let result):
                switch result {
                case .success(let gallery):
                    state.toast = nil
                    if state.isAwaitingDetailDismissal {
                        state.pendingGalleryLink = .init(url: url, gallery: gallery)
                        return .none
                    }
                    return .send(.handleGalleryLink(url: url, gallery: gallery))
                case .failure(let error):
                    let context = Context.galleryFailure(
                        url: url,
                        action: "Fetch gallery",
                        reason: error.localizedDescription
                    )
                    let errorInfo = ErrorInfo(error: error, context: context)
                    state.toast = .error(errorInfo)
                    return .none
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

extension PresentationFeature.Destination.State: Equatable, Sendable {}
extension PresentationFeature.Destination.Action: Equatable, Sendable {}
