//
//  FavoritesReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/29.
//

import SwiftUI
import IdentifiedCollections
import ComposableArchitecture

@Reducer
struct FavoritesReducer {
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

    var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.route) { _, newValue in
                Reduce({ _, _ in newValue == nil ? .send(.clearSubStates) : .none })
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

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
                return .run { [state] send in
                    let response = await FavoritesGalleriesRequest(
                        favIndex: state.index, keyword: state.keyword, sortOrder: sortOrder
                    )
                    .response()
                    await send(.fetchGalleriesDone(state.index, response))
                }

            case .fetchGalleriesDone(let targetFavIndex, let result):
                state.rawLoadingState[targetFavIndex] = .idle
                switch result {
                case .success(let (pageNumber, sortOrder, galleries)):
                    guard !galleries.isEmpty else {
                        state.rawLoadingState[targetFavIndex] = .failed(.notFound)
                        guard pageNumber.hasNextPage() else { return .none }
                        return .send(.fetchMoreGalleries)
                    }
                    state.rawPageNumber[targetFavIndex] = pageNumber
                    state.rawGalleries[targetFavIndex] = galleries
                    state.sortOrder = sortOrder
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
                return .run { [state] send in
                    let response = await MoreFavoritesGalleriesRequest(
                        favIndex: state.index,
                        lastID: lastID,
                        lastTimestamp: lastItemTimestamp,
                        keyword: state.keyword
                    )
                    .response()
                    await send(.fetchMoreGalleriesDone(state.index, response))
                }

            case .fetchMoreGalleriesDone(let targetFavIndex, let result):
                state.rawFooterLoadingState[targetFavIndex] = .idle
                switch result {
                case .success(let (pageNumber, sortOrder, galleries)):
                    state.rawPageNumber[targetFavIndex] = pageNumber
                    state.insertGalleries(index: targetFavIndex, galleries: galleries)
                    state.sortOrder = sortOrder

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
