//
//  FavoritesReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/29.
//

import SwiftUI
import IdentifiedCollections
import ComposableArchitecture

struct FavoritesReducer: ReducerProtocol {
    enum Route: Equatable {
        case quickSearch
        case detail(String)
    }

    struct State: Equatable {
        @BindingState var route: Route?
        @BindingState var keyword = ""

        var index = -1
        var sortOrder: FavoritesSortOrder?

        var rawGalleries = [Int: [Gallery]]()
        var rawPageNumber = [Int: PageNumber]()
        var rawLoadingState = [Int: LoadingState]()
        var rawFooterLoadingState = [Int: LoadingState]()

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

        @Heap var detailState: DetailReducer.State!
        var quickSearchState = QuickSearchReducer.State()

        init() {
            _detailState = .init(.init())
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
        case setNavigation(Route?)
        case setFavoritesIndex(Int)
        case clearSubStates
        case onNotLoginViewButtonTapped

        case fetchGalleries(String? = nil, FavoritesSortOrder? = nil)
        case fetchGalleriesDone(Int, Result<(PageNumber, FavoritesSortOrder?, [Gallery]), AppError>)
        case fetchMoreGalleries
        case fetchMoreGalleriesDone(Int, Result<(PageNumber, FavoritesSortOrder?, [Gallery]), AppError>)

        case detail(DetailReducer.Action)
        case quickSearch(QuickSearchReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticsClient) private var hapticsClient

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.$route):
                return state.route == nil ? .init(value: .clearSubStates) : .none

            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .init(value: .clearSubStates) : .none

            case .setFavoritesIndex(let index):
                state.index = index
                guard state.galleries?.isEmpty != false else { return .none }
                return .init(value: Action.fetchGalleries())

            case .clearSubStates:
                state.detailState = .init()
                return .init(value: .detail(.teardown))

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
                return FavoritesGalleriesRequest(
                    favIndex: state.index, keyword: state.keyword, sortOrder: sortOrder
                )
                .effect.map { [index = state.index] result in Action.fetchGalleriesDone(index, result) }

            case .fetchGalleriesDone(let targetFavIndex, let result):
                state.rawLoadingState[targetFavIndex] = .idle
                switch result {
                case .success(let (pageNumber, sortOrder, galleries)):
                    guard !galleries.isEmpty else {
                        state.rawLoadingState[targetFavIndex] = .failed(.notFound)
                        guard pageNumber.hasNextPage() else { return .none }
                        return .init(value: .fetchMoreGalleries)
                    }
                    state.rawPageNumber[targetFavIndex] = pageNumber
                    state.rawGalleries[targetFavIndex] = galleries
                    state.sortOrder = sortOrder
                    return databaseClient.cacheGalleries(galleries).fireAndForget()
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
                return MoreFavoritesGalleriesRequest(
                    favIndex: state.index,
                    lastID: lastID,
                    lastTimestamp: lastItemTimestamp,
                    keyword: state.keyword
                )
                .effect.map { [index = state.index] result in Action.fetchMoreGalleriesDone(index, result) }

            case .fetchMoreGalleriesDone(let targetFavIndex, let result):
                state.rawFooterLoadingState[targetFavIndex] = .idle
                switch result {
                case .success(let (pageNumber, sortOrder, galleries)):
                    state.rawPageNumber[targetFavIndex] = pageNumber
                    state.insertGalleries(index: targetFavIndex, galleries: galleries)
                    state.sortOrder = sortOrder

                    var effects: [EffectTask<Action>] = [
                        databaseClient.cacheGalleries(galleries).fireAndForget()
                    ]
                    if galleries.isEmpty, pageNumber.hasNextPage() {
                        effects.append(.init(value: .fetchMoreGalleries))
                    } else if !galleries.isEmpty {
                        state.rawLoadingState[targetFavIndex] = .idle
                    }
                    return .merge(effects)

                case .failure(let error):
                    state.rawFooterLoadingState[targetFavIndex] = .failed(error)
                }
                return .none

            case .detail:
                return .none

            case .quickSearch:
                return .none
            }
        }
        .haptics(
            unwrapping: \.route,
            case: /Route.quickSearch,
            hapticsClient: hapticsClient
        )

        Scope(state: \.detailState, action: /Action.detail, child: DetailReducer.init)
        Scope(state: \.quickSearchState, action: /Action.quickSearch, child: QuickSearchReducer.init)
    }
}
