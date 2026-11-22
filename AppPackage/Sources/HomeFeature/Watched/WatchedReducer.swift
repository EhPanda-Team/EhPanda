import AnalyticsClient
public import AppModels
import AppTools
public import ComposableArchitecture
import CookieClient
public import DateSeekFeature
public import DetailFeature
import DownloadClient
public import FiltersFeature
import GalleryClient
import HapticsClient
public import NetworkingFeature
public import QuickSearchFeature
public import Sharing

@Reducer
public struct WatchedReducer: Sendable {
    public enum Delegate: Equatable, Sendable {
        case pushDetail(Gallery)
    }

    @Reducer
    public enum Destination {
        case filters(FiltersReducer)
        case quickSearch(QuickSearchReducer)
        case dateSeek(DateSeekReducer)
    }

    private enum CancelID {
        case observeLogin
        case fetchGalleries, fetchMoreGalleries, observeDownloads, fetchDateSeekGalleries
    }

    @ObservableState
    public struct State: Equatable {
        @SharedReader(.watchedFilter) public var watchedFilter: Filter
        @SharedReader(.tagTranslator) public var tagTranslator: TagTranslator
        @SharedReader(.setting) public var setting: Setting
        public var reading = GalleryReadingFeature.State()
        @Presents public var destination: Destination.State?
        public var keyword = ""

        public var galleries = [Gallery]()
        public var pageNumber = PageNumber()
        public var dateSeekNavigation: DateSeekNavigation?
        public var loadingState: LoadingState = .idle
        public var footerLoadingState: LoadingState = .idle
        public var downloadBadges = [String: DownloadBadge]()

        public init() {}

    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onPresented
        case loginSucceeded
        case delegate(Delegate)
        case reading(GalleryReadingFeature.Action)
        case filtersButtonTapped
        case quickSearchButtonTapped
        case dateSeekButtonTapped(DateSeekNavigation)
        case destination(PresentationAction<Destination.Action>)
        case onNotLoginViewButtonTapped

        case fetchGalleries(String? = nil)
        case fetchGalleriesDone(Result<GalleriesResult, AppError>)
        case fetchMoreGalleries
        case fetchMoreGalleriesDone(Result<GalleriesResult, AppError>)
        case observeDownloads
        case observeDownloadsDone([DownloadedGallery])
        case performDateSeekDone(Result<GalleriesResult, AppError>)
    }

    @Dependency(\.analyticsClient) private var analyticsClient
    @Dependency(\.cookieClient) private var cookieClient
    @Dependency(\.downloadClient) private var downloadClient
    @Dependency(\.galleryClient) private var galleryClient
    @Dependency(\.hapticsClient) private var hapticsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
        Scope(\.reading, action: \.reading, GalleryReadingFeature.init)

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            // Presentation-driven lifecycle: the presenting reducer sends this as part of the
            // state transition that pushes this screen, replacing the former view `onAppear`.
            // The empty guard keeps it idempotent — re-presenting a populated list refetches nothing.
            // Watched is login-gated, so a logged-out visit shows the sign-in overlay and fetches
            // nothing, exactly as the view's `didLogin` check did.
            case .onPresented:
                // Subscribe before returning the effect so a login during presentation is buffered.
                let changes = cookieClient.cookiesDidChange()
                let initiallyLoggedIn = cookieClient.didLogin
                let observeLogin: Effect<Action> = .run { send in
                    var wasLoggedIn = initiallyLoggedIn
                    for await _ in changes {
                        let isLoggedIn = cookieClient.didLogin
                        if !wasLoggedIn && isLoggedIn {
                            await send(.loginSucceeded)
                        }
                        wasLoggedIn = isLoggedIn
                    }
                }
                .cancellable(id: CancelID.observeLogin, cancelInFlight: true)
                guard state.galleries.isEmpty, initiallyLoggedIn else {
                    return .merge(observeLogin, .send(.observeDownloads))
                }
                return .merge(observeLogin, .send(.observeDownloads), .send(.fetchGalleries()))

            case .loginSucceeded:
                guard state.galleries.isEmpty else { return .none }
                return .send(.fetchGalleries())

            case .delegate(.pushDetail):
                state.reading.cancelOpening()
                return .none

            case .reading:
                return .none

            case .filtersButtonTapped:
                state.destination = .filters(FiltersReducer.State())
                // Presenting the sheet loads the persisted filters into it, replacing the form's
                // former `onAppear`. Every screen that presents Filters must send this.
                // Records that the filter panel was opened here (D-14). Applying a filter mutates a
                // persisted shared value with no distinct reducer action, so only the open is counted.
                return .merge(
                    .send(.destination(.presented(.filters(.fetchFilters)))),
                    .run(operation: { _ in analyticsClient.send(.filterPanelOpened(.watched)) })
                )

            case .quickSearchButtonTapped:
                state.destination = .quickSearch(QuickSearchReducer.State())
                // Records that the quick-search panel was opened from the Watched surface (D-14).
                return .run(operation: { _ in analyticsClient.send(.quickSearchPanelOpened(.watched)) })

            case .dateSeekButtonTapped(let navigation):
                state.destination = .dateSeek(.init(navigation: navigation))
                return .none

            case .onNotLoginViewButtonTapped:
                return .none

            case .fetchGalleries(let keyword):
                guard state.loadingState != .loading else { return .none }
                if let keyword = keyword {
                    state.keyword = keyword
                }
                state.loadingState = .loading
                state.pageNumber.resetPages()
                let filter = state.watchedFilter
                let host = state.setting.galleryHost
                return .run { [keyword = state.keyword] send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await galleryClient.fetchWatchedGalleries(host, filter, keyword)
                    }
                    await send(.fetchGalleriesDone(result))
                }
                .cancellable(id: CancelID.fetchGalleries)

            case .fetchGalleriesDone(let result):
                state.loadingState = .idle
                switch result {
                case .success(let response):
                    // The page's cursor is kept even when the page is empty, since the next page is fetched from it.
                    state.pageNumber = response.pageNumber
                    state.dateSeekNavigation = response.dateSeekNavigation
                    state.galleries = response.galleries
                    guard response.galleries.isEmpty else { return .none }
                    state.loadingState = .failed(.notFound)
                    return response.pageNumber.hasNextPage() ? .send(.fetchMoreGalleries) : .none
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .fetchMoreGalleries:
                guard state.footerLoadingState != .loading,
                      let cursor = state.pageNumber.nextCursor
                else { return .none }
                state.footerLoadingState = .loading
                let filter = state.watchedFilter
                let host = state.setting.galleryHost
                return .run { [keyword = state.keyword] send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await galleryClient.fetchMoreWatchedGalleries(host, filter, cursor, keyword)
                    }
                    await send(.fetchMoreGalleriesDone(result))
                }
                .cancellable(id: CancelID.fetchMoreGalleries)

            case .fetchMoreGalleriesDone(let result):
                state.footerLoadingState = .idle
                switch result {
                case .success(let response):
                    let previous = state.pageNumber
                    state.pageNumber = response.pageNumber
                    state.dateSeekNavigation = response.dateSeekNavigation
                    if state.galleries.appendNew(response.galleries) > 0 {
                        state.loadingState = .idle
                        return .none
                    }
                    // Nothing new leaves the last gallery where it was, so no scroll will ask again: go on from here.
                    return response.pageNumber.advances(from: previous) ? .send(.fetchMoreGalleries) : .none

                case .failure(let error):
                    state.footerLoadingState = .failed(error)
                }
                return .none

            case .observeDownloads:
                return .run { send in
                    for await downloads in downloadClient.observeDownloads() {
                        await send(.observeDownloadsDone(downloads))
                    }
                }
                .cancellable(id: CancelID.observeDownloads, cancelInFlight: true)

            case .observeDownloadsDone(let downloads):
                state.downloadBadges = Dictionary(
                    uniqueKeysWithValues: downloads.map({ ($0.gid, $0.badge) })
                )
                return .none

            case .destination(.presented(.dateSeek(.delegate(.performSeek(let url))))):
                guard state.loadingState != .loading else { return .none }
                state.loadingState = .loading
                state.footerLoadingState = .idle
                state.pageNumber.resetPages()
                let host = state.setting.galleryHost
                return .run { send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await galleryClient.fetchDateSeekGalleries(host, url)
                    }
                    await send(.performDateSeekDone(result))
                }
                .cancellable(id: CancelID.fetchDateSeekGalleries)

            case .performDateSeekDone(let result):
                state.loadingState = .idle
                switch result {
                case .success(let response):
                    let galleries = response.galleries
                    guard !galleries.isEmpty else {
                        state.loadingState = .failed(.notFound)
                        return .none
                    }
                    state.pageNumber = response.pageNumber
                    state.dateSeekNavigation = response.dateSeekNavigation
                    state.galleries = galleries
                    return .none
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .destination:
                return .none
            }
        }
        .haptics(
            unwrapping: \.destination,
            case: \.quickSearch,
            hapticsClient: hapticsClient
        )
        .haptics(
            unwrapping: \.destination,
            case: \.filters,
            hapticsClient: hapticsClient
        )
        .haptics(
            unwrapping: \.destination,
            case: \.dateSeek,
            hapticsClient: hapticsClient
        )
        .ifLet(\.$destination, action: \.destination)
        .signalsErrors(of: \.loadingState.failed, on: .watched)
        .signalsErrors(of: \.footerLoadingState.failed, on: .watched)
    }
}

extension WatchedReducer.Destination.State: Equatable, Sendable {}
