import AnalyticsClient
public import AppModels
import AppTools
public import ComposableArchitecture
import CookieClient
public import DateSeekFeature
public import DetailFeature
import DownloadClient
import GalleryClient
import HapticsClient
import IdentifiedCollections
public import NetworkingFeature
public import QuickSearchFeature
import SwiftUI

@Reducer
public struct FavoritesReducer: Sendable {
    @CasePathable
    public enum Delegate: Equatable, Sendable {
        /// Asks the app root to open a gallery's detail. The root knows the window's size classes,
        /// so it decides between a modal and `pushGalleryDetail` back to this host.
        case openGalleryDetail(Gallery)
    }

    private enum CancelID {
        case observeLogin
        case observeDownloads
    }

    @Reducer
    public enum Destination {
        case quickSearch(QuickSearchReducer)
        case dateSeek(DateSeekReducer)
    }

    @ObservableState
    public struct State: Equatable {
        @SharedReader(.tagTranslator) public var tagTranslator: TagTranslator
        @SharedReader(.user) public var user: User
        @SharedReader(.setting) public var setting: Setting
        public var path = StackState<GalleryPath.State>()
        @Presents public var destination: Destination.State?
        public var reading = GalleryReadingFeature.State()
        public var keyword = ""
        public var visibleGalleryID: String?

        public var favoritesIndex = -1
        public var sortOrder: FavoritesSortOrder?

        public var rawGalleries = [Int: [Gallery]]()
        public var rawPageNumber = [Int: PageNumber]()
        public var rawDateSeekNavigation = [Int: DateSeekNavigation]()
        public var rawLoadingState = [Int: LoadingState]()
        public var rawFooterLoadingState = [Int: LoadingState]()
        public var downloadBadges = [String: DownloadBadge]()
        /// The categories whose last load succeeded with nothing in them: nothing saved there yet, which
        /// Favorites shows as its own empty state. A keyword search or a date-seek with no hits is "no
        /// results" instead and stays `.failed(.notFound)` (owner decision).
        public var emptyFavoritesIndices = Set<Int>()

        var galleries: [Gallery]? {
            rawGalleries[favoritesIndex]
        }
        var pageNumber: PageNumber? {
            rawPageNumber[favoritesIndex]
        }
        var dateSeekNavigation: DateSeekNavigation? {
            rawDateSeekNavigation[favoritesIndex]
        }
        var loadingState: LoadingState? {
            rawLoadingState[favoritesIndex]
        }
        var footerLoadingState: LoadingState? {
            rawFooterLoadingState[favoritesIndex]
        }
        /// Whether the current category is loaded and has nothing saved in it.
        var isEmpty: Bool {
            loadingState == .idle && emptyFavoritesIndices.contains(favoritesIndex)
        }

        public init() {}
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onPresented
        case loginSucceeded
        case delegate(Delegate)
        case galleryTapped(Gallery)
        case reading(GalleryReadingFeature.Action)
        case pushGalleryDetail(Gallery)
        case path(StackActionOf<GalleryPath>)
        case setFavoritesIndex(Int)
        case selectSortOrder(FavoritesSortOrder?)
        case quickSearchButtonTapped
        case dateSeekButtonTapped(DateSeekNavigation)
        case destination(PresentationAction<Destination.Action>)
        case onNotLoginViewButtonTapped

        case fetchGalleries(keyword: String? = nil, sortOrder: FavoritesSortOrder? = nil)
        case fetchGalleriesDone(index: Int, keyword: String, result: Result<FavoritesGalleriesResult, AppError>)
        case fetchMoreGalleries
        case fetchMoreGalleriesDone(index: Int, result: Result<FavoritesGalleriesResult, AppError>)
        case observeDownloads
        case observeDownloadsDone([DownloadedGallery])
        case performDateSeekDone(index: Int, result: Result<GalleriesResult, AppError>)
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

            // Presentation-driven lifecycle: Favorites is a tab root that outlives any single
            // visit, so the app reducer sends this when the Favorites tab becomes the active one —
            // replacing the former view `onAppear`. The guards keep it idempotent across tab
            // switches, and a logged-out visit shows the sign-in overlay without fetching, exactly
            // as the view's `didLogin` check did.
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
                guard state.galleries?.isEmpty != false, initiallyLoggedIn else {
                    return .merge(observeLogin, .send(.observeDownloads))
                }
                return .merge(observeLogin, .send(.observeDownloads), .send(.fetchGalleries()))

            case .loginSucceeded:
                guard state.galleries?.isEmpty != false else { return .none }
                return .send(.fetchGalleries())

            case .galleryTapped(let gallery):
                state.reading.cancelOpening()
                return .send(.delegate(.openGalleryDetail(gallery)))

            case .pushGalleryDetail(let gallery):
                let screen = GalleryPath.State.detail(.init(gallery: gallery))
                return .merge(
                    GalleryNavigation.presentationEffect(
                        id: state.path.appendGuardingDuplicate(screen),
                        screen: screen,
                        embed: { .path(.element(id: $0, action: $1)) }
                    ),
                    // Same content-free derivation as the other four gallery-detail entry paths: a
                    // closed `Category` plus exact per-namespace tag counts — no gid, token, title,
                    // URL or tag text (D-06, D-09).
                    .run(operation: { _ in
                        analyticsClient.send(.galleryDetailOpened(
                            category: gallery.category,
                            tagNamespaces: TagNamespaceCounts(tags: gallery.tags)
                        ))
                    })
                )

            case .delegate:
                return .none

            // A vote's answer goes to the detail's own copy of the comment, with no fetch of the whole detail.
            case let .path(.element(id: _, action: .comments(.delegate(.commentVoted(gid, commentID, score, vote))))):
                guard let id = state.path.detailID(forGID: gid) else { return .none }
                return .send(.path(.element(id: id, action: .detail(
                    .applyCommentVote(commentID: commentID, score: score, vote: vote)
                ))))

            case let .path(.element(id: _, action: .comments(.delegate(.performedCommentAction(gid))))):
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

            case .selectSortOrder(let order):
                guard let order, order != state.sortOrder else { return .none }
                // Selection reflects the server-confirmed order; failures keep the existing mark.
                return .send(.fetchGalleries(sortOrder: order))

            case .setFavoritesIndex(let index):
                guard index != state.favoritesIndex else { return .none }
                state.favoritesIndex = index
                state.reading.cancelOpening()
                guard cookieClient.didLogin else { return .none }
                guard state.galleries?.isEmpty != false else { return .none }
                return .send(.fetchGalleries())

            case .quickSearchButtonTapped:
                state.destination = .quickSearch(QuickSearchReducer.State())
                // Records that the quick-search panel was opened from the Favorites surface (D-14).
                return .run(operation: { _ in analyticsClient.send(.quickSearchPanelOpened(.favorites)) })

            case .dateSeekButtonTapped(let navigation):
                state.destination = .dateSeek(.init(navigation: navigation))
                return .none

            case .onNotLoginViewButtonTapped:
                return .none

            case .fetchGalleries(let keyword, let sortOrder):
                guard state.loadingState != .loading else { return .none }
                state.rawLoadingState[state.favoritesIndex] = .loading
                if let keyword = keyword {
                    state.keyword = keyword
                }
                if state.pageNumber == nil {
                    state.rawPageNumber[state.favoritesIndex] = PageNumber()
                } else {
                    state.rawPageNumber[state.favoritesIndex]?.resetPages()
                }
                let host = state.setting.galleryHost
                return .run { [index = state.favoritesIndex, keyword = state.keyword] send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await galleryClient.fetchFavoritesGalleries(host, index, keyword, sortOrder)
                    }
                    await send(.fetchGalleriesDone(index: index, keyword: keyword, result: result))
                }

            case .fetchGalleriesDone(let targetFavIndex, let keyword, let result):
                state.rawLoadingState[targetFavIndex] = .idle
                state.emptyFavoritesIndices.remove(targetFavIndex)
                switch result {
                case .success(let fetchResult):
                    let pageNumber = fetchResult.pageNumber
                    let galleries = fetchResult.galleries
                    // The page's cursor is kept even when the page is empty, since the next page is fetched from it.
                    state.rawPageNumber[targetFavIndex] = pageNumber
                    state.rawDateSeekNavigation[targetFavIndex] = fetchResult.dateSeekNavigation
                    state.rawGalleries[targetFavIndex] = galleries
                    guard !galleries.isEmpty else {
                        // A keyword search with no hits is "no results": the shared not-found error.
                        guard keyword.isEmpty else {
                            state.rawLoadingState[targetFavIndex] = .failed(.notFound)
                            return pageNumber.hasNextPage() ? .send(.fetchMoreGalleries) : .none
                        }
                        // Nothing saved in this category: its own empty state, not an error.
                        state.emptyFavoritesIndices.insert(targetFavIndex)
                        return .none
                    }
                    // A page whose order was not read keeps the order the server last confirmed.
                    if let sortOrder = fetchResult.sortOrder {
                        state.sortOrder = sortOrder
                    }
                    return .none
                case .failure(let error):
                    state.rawLoadingState[targetFavIndex] = .failed(error)
                }
                return .none

            case .fetchMoreGalleries:
                guard state.footerLoadingState != .loading,
                      let cursor = state.pageNumber?.nextCursor
                else { return .none }
                state.rawFooterLoadingState[state.favoritesIndex] = .loading
                let host = state.setting.galleryHost
                return .run { [index = state.favoritesIndex, keyword = state.keyword] send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await galleryClient.fetchMoreFavoritesGalleries(host, index, cursor, keyword)
                    }
                    await send(.fetchMoreGalleriesDone(index: index, result: result))
                }

            case .fetchMoreGalleriesDone(let targetFavIndex, let result):
                state.rawFooterLoadingState[targetFavIndex] = .idle
                switch result {
                case .success(let fetchResult):
                    let previous = state.rawPageNumber[targetFavIndex] ?? .init()
                    state.rawPageNumber[targetFavIndex] = fetchResult.pageNumber
                    state.rawDateSeekNavigation[targetFavIndex] = fetchResult.dateSeekNavigation
                    if let sortOrder = fetchResult.sortOrder {
                        state.sortOrder = sortOrder
                    }
                    if state.rawGalleries[targetFavIndex, default: []].appendNew(fetchResult.galleries) > 0 {
                        state.rawLoadingState[targetFavIndex] = .idle
                        return .none
                    }
                    // Nothing new leaves the last gallery where it was, so no scroll will ask again: go on from here.
                    return fetchResult.pageNumber.advances(from: previous) ? .send(.fetchMoreGalleries) : .none

                case .failure(let error):
                    state.rawFooterLoadingState[targetFavIndex] = .failed(error)
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
                state.rawLoadingState[state.favoritesIndex] = .loading
                state.rawFooterLoadingState[state.favoritesIndex] = .idle
                state.rawPageNumber[state.favoritesIndex]?.resetPages()
                let host = state.setting.galleryHost
                return .run { [index = state.favoritesIndex] send in
                    let result = await Result.Swift::init { () async throws(AppError) in
                        try await galleryClient.fetchDateSeekGalleries(host, url)
                    }
                    await send(.performDateSeekDone(index: index, result: result))
                }

            case .performDateSeekDone(let targetFavIndex, let result):
                state.rawLoadingState[targetFavIndex] = .idle
                state.emptyFavoritesIndices.remove(targetFavIndex)
                switch result {
                case .success(let response):
                    let galleries = response.galleries
                    guard !galleries.isEmpty else {
                        state.rawLoadingState[targetFavIndex] = .failed(.notFound)
                        return .none
                    }
                    state.rawPageNumber[targetFavIndex] = response.pageNumber
                    state.rawDateSeekNavigation[targetFavIndex] = response.dateSeekNavigation
                    state.rawGalleries[targetFavIndex] = galleries
                    return .none
                case .failure(let error):
                    state.rawLoadingState[targetFavIndex] = .failed(error)
                }
                return .none

            case .destination, .reading:
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
            case: \.dateSeek,
            hapticsClient: hapticsClient
        )
        .ifLet(\.$destination, action: \.destination)
        .forEach(\.path, action: \.path)
        .signalsErrors(of: \.rawLoadingState, on: .favorites)
        .signalsErrors(of: \.rawFooterLoadingState, on: .favorites)
    }
}

extension FavoritesReducer.Destination.State: Equatable, Sendable {}
