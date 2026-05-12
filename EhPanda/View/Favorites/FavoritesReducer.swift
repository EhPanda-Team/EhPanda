//
//  FavoritesReducer.swift
//  EhPanda
//

import SwiftUI
import IdentifiedCollections
import ComposableArchitecture

@Reducer
struct FavoritesReducer {
    private enum CancelID {
        case observeDownloads
    }

    @CasePathable
    enum Route: Equatable {
        case quickSearch(EquatableVoid = .init())
        case detail(String)
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?
        var keyword = ""

        var index = -1
        var sortOrder: FavoritesSortOrder?

        var rawGalleries = [Int: [Gallery]]()
        var rawPageNumber = [Int: PageNumber]()
        var rawLoadingState = [Int: LoadingState]()
        var rawFooterLoadingState = [Int: LoadingState]()
        var downloadBadges = [String: DownloadBadge]()

        var galleries: [Gallery]? {
            rawGalleries[index]
        }
        var pageNumber: PageNumber? {
            rawPageNumber[index]
        }
        var loadingState: LoadingState? {
            rawLoadingState[index]
        }
        var footerLoadingState: LoadingState? {
            rawFooterLoadingState[index]
        }

        var detailState: Heap<DetailReducer.State?>
        var quickSearchState = QuickSearchReducer.State()

        init() {
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

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case onAppear
        case setNavigation(Route?)
        case setFavoritesIndex(Int)
        case clearSubStates
        case onNotLoginViewButtonTapped

        case fetchGalleries(String? = nil, FavoritesSortOrder? = nil)
        case fetchGalleriesDone(Int, Result<FavoritesGalleriesResult, AppError>)
        case fetchMoreGalleries
        case fetchMoreGalleriesDone(Int, Result<FavoritesGalleriesResult, AppError>)
        case fetchDownloadBadges([String])
        case fetchDownloadBadgesDone([String: DownloadBadge])
        case observeDownloads
        case observeDownloadsDone([DownloadedGallery])

        case detail(DetailReducer.Action)
        case quickSearch(QuickSearchReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.downloadClient) private var downloadClient
    @Dependency(\.hapticsClient) private var hapticsClient

    var body: some Reducer<State, Action> {
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
                    state.rawGalleries[targetFavIndex] = galleries
                    state.sortOrder = fetchResult.sortOrder
                    return .merge(
                        .run(operation: { _ in await databaseClient.cacheGalleries(galleries) }),
                        .send(.fetchDownloadBadges(galleries.map(\.gid)))
                    )
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
                    state.insertGalleries(index: targetFavIndex, galleries: galleries)
                    state.sortOrder = fetchResult.sortOrder

                    var effects: [Effect<Action>] = [
                        .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                    ]
                    if galleries.isEmpty, pageNumber.hasNextPage() {
                        effects.append(.send(.fetchMoreGalleries))
                    } else if !galleries.isEmpty {
                        state.rawLoadingState[targetFavIndex] = .idle
                        effects.append(.send(.fetchDownloadBadges((state.galleries ?? []).map(\.gid))))
                    }
                    return .merge(effects)

                case .failure(let error):
                    state.rawFooterLoadingState[targetFavIndex] = .failed(error)
                }
                return .none

            case .fetchDownloadBadges(let gids):
                return .run { send in
                    await send(.fetchDownloadBadgesDone(await downloadClient.badges(gids)))
                }

            case .fetchDownloadBadgesDone(let badges):
                state.downloadBadges.merge(badges, uniquingKeysWith: { _, new in new })
                return .none

            case .observeDownloads:
                return .run { send in
                    for await downloads in downloadClient.observeDownloads() {
                        await send(.observeDownloadsDone(downloads))
                    }
                }
                .cancellable(id: CancelID.observeDownloads, cancelInFlight: true)

            case .observeDownloadsDone(let downloads):
                let visibleGIDs = Set((state.galleries ?? []).map(\.gid))
                state.downloadBadges = Dictionary(
                    uniqueKeysWithValues: downloads.compactMap { download in
                        guard visibleGIDs.contains(download.gid) else { return nil }
                        return (download.gid, download.badge)
                    }
                )
                return .none

            case .detail:
                return .none

            case .quickSearch:
                return .none
            }
        }
        .haptics(
            unwrapping: \.route,
            case: \.quickSearch,
            hapticsClient: hapticsClient
        )

        Scope(state: \.detailState.wrappedValue!, action: \.detail, child: DetailReducer.init)
        Scope(state: \.quickSearchState, action: \.quickSearch, child: QuickSearchReducer.init)
    }
}
