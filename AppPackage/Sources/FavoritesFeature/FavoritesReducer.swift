import AppTools
import SwiftUI
import AppModels
import IdentifiedCollections
import ComposableArchitecture
import SwiftUINavigationExt
import HapticsClient
import DatabaseClient
import NetworkingFeature
import DownloadClient
import DateSeekFeature
import QuickSearchFeature
import DetailFeature
import ComposableArchitectureExt

@Reducer
public struct FavoritesReducer: Sendable {
    private enum CancelID {
        case observeDownloads
    }

    @CasePathable
    public enum Route: Equatable, Sendable {
        case detail(String)
    }

    @Reducer
    public enum Destination {
        case quickSearch(QuickSearchReducer)
        case dateSeek(DateSeekReducer)
    }

    @ObservableState
    public struct State: Equatable {
        public var route: Route?
        @Presents public var destination: Destination.State?
        public var keyword = ""

        public var index = -1
        public var sortOrder: FavoritesSortOrder?

        public var rawGalleries = [Int: [Gallery]]()
        public var rawPageNumber = [Int: PageNumber]()
        public var rawDateSeekNavigation = [Int: DateSeekNavigation]()
        public var rawLoadingState = [Int: LoadingState]()
        public var rawFooterLoadingState = [Int: LoadingState]()
        public var downloadBadges = [String: DownloadBadge]()

        var galleries: [Gallery]? {
            rawGalleries[index]
        }
        var pageNumber: PageNumber? {
            rawPageNumber[index]
        }
        var dateSeekNavigation: DateSeekNavigation? {
            rawDateSeekNavigation[index]
        }
        var loadingState: LoadingState? {
            rawLoadingState[index]
        }
        var footerLoadingState: LoadingState? {
            rawFooterLoadingState[index]
        }

        public var detailState: Heap<DetailReducer.State?>

        public init() {
            detailState = .init(.init())
        }

        mutating func insertGalleries(index: Int, galleries: [Gallery]) {
            galleries.forEach { gallery in
                if rawGalleries[index]?.contains(gallery) == false {
                    rawGalleries[index]?.append(gallery)
                }
            }
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case setNavigation(Route?)
        case setFavoritesIndex(Int)
        case clearSubStates
        case quickSearchButtonTapped
        case dateSeekButtonTapped(DateSeekNavigation)
        case destination(PresentationAction<Destination.Action>)
        case onNotLoginViewButtonTapped

        case fetchGalleries(String? = nil, FavoritesSortOrder? = nil)
        case fetchGalleriesDone(Int, Result<FavoritesGalleriesResult, AppError>)
        case fetchMoreGalleries
        case fetchMoreGalleriesDone(Int, Result<FavoritesGalleriesResult, AppError>)
        case observeDownloads
        case observeDownloadsDone([DownloadedGallery])
        case performDateSeekDone(Int, Result<GalleriesResult, AppError>)

        case detail(DetailReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.downloadClient) private var downloadClient
    @Dependency(\.hapticsClient) private var hapticsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.route) { _, state in
                state.route == nil ? .send(.clearSubStates) : .none
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .onAppear:
                return .send(.observeDownloads)

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .send(.clearSubStates) : .none

            case .setFavoritesIndex(let index):
                state.index = index
                guard state.galleries?.isEmpty != false else { return .none }
                return .send(.fetchGalleries())

            case .clearSubStates:
                state.detailState.wrappedValue = .init()
                return .send(.detail(.teardown))

            case .quickSearchButtonTapped:
                state.destination = .quickSearch(QuickSearchReducer.State())
                return .none

            case .dateSeekButtonTapped(let navigation):
                state.destination = .dateSeek(.init(navigation: navigation))
                return .none

            case .onNotLoginViewButtonTapped:
                return .none

            case .fetchGalleries(let keyword, let sortOrder):
                guard state.loadingState != .loading else { return .none }
                state.rawLoadingState[state.index] = .loading
                if let keyword = keyword {
                    state.keyword = keyword
                }
                if state.pageNumber == nil {
                    state.rawPageNumber[state.index] = PageNumber()
                } else {
                    state.rawPageNumber[state.index]?.resetPages()
                }
                return .run { [index = state.index, keyword = state.keyword] send in
                    let response = await FavoritesGalleriesRequest(
                        favIndex: index, keyword: keyword, sortOrder: sortOrder
                    )
                    .response()
                    await send(.fetchGalleriesDone(index, response))
                }

            case .fetchGalleriesDone(let targetFavIndex, let result):
                state.rawLoadingState[targetFavIndex] = .idle
                switch result {
                case .success(let fetchResult):
                    let pageNumber = fetchResult.pageNumber
                    let galleries = fetchResult.galleries
                    guard !galleries.isEmpty else {
                        state.rawLoadingState[targetFavIndex] = .failed(.notFound)
                        guard pageNumber.hasNextPage() else { return .none }
                        return .send(.fetchMoreGalleries)
                    }
                    state.rawPageNumber[targetFavIndex] = pageNumber
                    state.rawDateSeekNavigation[targetFavIndex] = fetchResult.dateSeekNavigation
                    state.rawGalleries[targetFavIndex] = galleries
                    state.sortOrder = fetchResult.sortOrder
                    return .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                case .failure(let error):
                    state.rawLoadingState[targetFavIndex] = .failed(error)
                }
                return .none

            case .fetchMoreGalleries:
                let pageNumber = state.pageNumber ?? .init()
                guard pageNumber.hasNextPage(),
                      state.footerLoadingState != .loading,
                      let lastID = state.galleries?.last?.id,
                      let lastItemTimestamp = pageNumber.lastItemTimestamp
                else { return .none }
                state.rawFooterLoadingState[state.index] = .loading
                return .run { [index = state.index, keyword = state.keyword] send in
                    let response = await MoreFavoritesGalleriesRequest(
                        favIndex: index,
                        lastID: lastID,
                        lastTimestamp: lastItemTimestamp,
                        keyword: keyword
                    )
                    .response()
                    await send(.fetchMoreGalleriesDone(index, response))
                }

            case .fetchMoreGalleriesDone(let targetFavIndex, let result):
                state.rawFooterLoadingState[targetFavIndex] = .idle
                switch result {
                case .success(let fetchResult):
                    let pageNumber = fetchResult.pageNumber
                    let galleries = fetchResult.galleries
                    state.rawPageNumber[targetFavIndex] = pageNumber
                    state.rawDateSeekNavigation[targetFavIndex] = fetchResult.dateSeekNavigation
                    state.insertGalleries(index: targetFavIndex, galleries: galleries)
                    state.sortOrder = fetchResult.sortOrder

                    var effects: [Effect<Action>] = [
                        .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                    ]
                    if galleries.isEmpty, pageNumber.hasNextPage() {
                        effects.append(.send(.fetchMoreGalleries))
                    } else if !galleries.isEmpty {
                        state.rawLoadingState[targetFavIndex] = .idle
                    }
                    return .merge(effects)

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
                    uniqueKeysWithValues: downloads.map { ($0.gid, $0.badge) }
                )
                return .none

            case .destination(.presented(.dateSeek(.delegate(.performSeek(let url))))):
                guard state.loadingState != .loading else { return .none }
                state.rawLoadingState[state.index] = .loading
                state.rawFooterLoadingState[state.index] = .idle
                state.rawPageNumber[state.index]?.resetPages()
                return .run { [index = state.index] send in
                    let response = await DateSeekGalleriesRequest(url: url).response()
                    await send(.performDateSeekDone(index, response))
                }

            case .performDateSeekDone(let targetFavIndex, let result):
                state.rawLoadingState[targetFavIndex] = .idle
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
                    return .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                case .failure(let error):
                    state.rawLoadingState[targetFavIndex] = .failed(error)
                }
                return .none

            case .destination:
                return .none

            case .detail:
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

        Scope(state: \.detailState.wrappedValue!, action: \.detail, child: DetailReducer.init)
    }
}

extension FavoritesReducer.Destination.State: Equatable, Sendable {}
