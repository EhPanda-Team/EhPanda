//
//  FavoritesStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/29.
//

import SwiftUI
import IdentifiedCollections
import ComposableArchitecture

// MARK: State
struct FavoritesState: Equatable {
    enum Route: Equatable {
        case detail(String)
    }

    @BindableState var route: Route?
    @BindableState var keyword = ""
    @BindableState var jumpPageIndex = ""
    @BindableState var jumpPageAlertFocused = false
    @BindableState var jumpPageAlertPresented = false

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

    var detailState = DetailState()

    mutating func insertGalleries(index: Int, galleries: [Gallery]) {
        galleries.forEach { gallery in
            if rawGalleries[index]?.contains(gallery) == false {
                rawGalleries[index]?.append(gallery)
            }
        }
    }
}

// MARK: Action
enum FavoritesAction: BindableAction {
    case binding(BindingAction<FavoritesState>)
    case setNavigation(FavoritesState.Route?)
    case setFavoritesIndex(Int)
    case clearSubStates
    case onDisappear

    case performJumpPage
    case presentJumpPageAlert
    case setJumpPageAlertFocused(Bool)

    case fetchGalleries(Int? = nil, FavoritesSortOrder? = nil)
    case fetchGalleriesDone(Int, Result<(PageNumber, FavoritesSortOrder?, [Gallery]), AppError>)
    case fetchMoreGalleries
    case fetchMoreGalleriesDone(Int, Result<(PageNumber, FavoritesSortOrder?, [Gallery]), AppError>)

    case detail(DetailAction)
}

// MARK: Environment
struct FavoritesEnvironment {
    let urlClient: URLClient
    let fileClient: FileClient
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
    let clipboardClient: ClipboardClient
    let uiApplicationClient: UIApplicationClient
}

// MARK: Reducer
let favoritesReducer = Reducer<FavoritesState, FavoritesAction, FavoritesEnvironment>.combine(
    .init { state, action, environment in
        switch action {
        case .binding(\.$route):
            return state.route == nil ? .init(value: .clearSubStates) : .none

        case .binding(\.$jumpPageAlertPresented):
            if !state.jumpPageAlertPresented {
                state.jumpPageAlertFocused = false
            }
            return .none

        case .binding:
            return .none

        case .setNavigation(let route):
            state.route = route
            return route == nil ? .init(value: .clearSubStates) : .none

        case .setFavoritesIndex(let index):
            state.index = index
            guard state.galleries?.isEmpty != false else { return .none }
            return .init(value: FavoritesAction.fetchGalleries())

        case .clearSubStates:
            state.detailState = .init()
            return .init(value: .detail(.cancelFetching))

        case .onDisappear:
            state.jumpPageAlertPresented = false
            state.jumpPageAlertFocused = false
            return .none

        case .performJumpPage:
            guard let index = Int(state.jumpPageIndex),
                  let pageNumber = state.pageNumber,
                  index > 0, index <= pageNumber.maximum + 1
            else {
                return environment.hapticClient.generateNotificationFeedback(.error).fireAndForget()
            }
            return .init(value: .fetchGalleries(index - 1))

        case .presentJumpPageAlert:
            state.jumpPageAlertPresented = true
            return environment.hapticClient.generateFeedback(.light).fireAndForget()

        case .setJumpPageAlertFocused(let isFocused):
            state.jumpPageAlertFocused = isFocused
            return .none

        case .fetchGalleries(let pageNum, let sortOrder):
            guard state.loadingState != .loading else { return .none }
            state.rawLoadingState[state.index] = .loading
            if state.pageNumber == nil {
                state.rawPageNumber[state.index] = PageNumber()
            } else {
                state.rawPageNumber[state.index]?.current = 0
            }
            return FavoritesGalleriesRequest(
                favIndex: state.index, pageNum: pageNum, keyword: state.keyword, sortOrder: sortOrder
            )
            .effect.map { [index = state.index] result in FavoritesAction.fetchGalleriesDone(index, result) }

        case .fetchGalleriesDone(let targetFavIndex, let result):
            state.rawLoadingState[targetFavIndex] = .idle
            switch result {
            case .success(let (pageNumber, sortOrder, galleries)):
                guard !galleries.isEmpty else {
                    guard pageNumber.current < pageNumber.maximum else {
                        state.rawLoadingState[targetFavIndex] = .failed(.notFound)
                        return .none
                    }
                    return .init(value: .fetchMoreGalleries)
                }
                state.rawPageNumber[targetFavIndex] = pageNumber
                state.rawGalleries[targetFavIndex] = galleries
                state.sortOrder = sortOrder
                return environment.databaseClient.cacheGalleries(galleries).fireAndForget()
            case .failure(let error):
                state.rawLoadingState[targetFavIndex] = .failed(error)
            }
            return .none

        case .fetchMoreGalleries:
            let pageNumber = state.pageNumber ?? PageNumber()
            guard pageNumber.current + 1 <= pageNumber.maximum,
                  state.footerLoadingState != .loading
            else { return .none }
            state.rawFooterLoadingState[state.index] = .loading
            let pageNum = pageNumber.current + 1
            let lastID = state.galleries?.last?.id ?? ""
            return MoreFavoritesGalleriesRequest(
                favIndex: state.index, lastID: lastID, pageNum: pageNum, keyword: state.keyword
            )
            .effect.map { [index = state.index] result in FavoritesAction.fetchMoreGalleriesDone(index, result) }

        case .fetchMoreGalleriesDone(let targetFavIndex, let result):
            state.rawFooterLoadingState[targetFavIndex] = .idle
            switch result {
            case .success(let (pageNumber, sortOrder, galleries)):
                state.rawPageNumber[targetFavIndex] = pageNumber
                state.insertGalleries(index: targetFavIndex, galleries: galleries)
                state.sortOrder = sortOrder

                var effects: [Effect<FavoritesAction, Never>] = [
                    environment.databaseClient.cacheGalleries(galleries).fireAndForget()
                ]
                if galleries.isEmpty, pageNumber.current < pageNumber.maximum {
                    effects.append(.init(value: .fetchMoreGalleries))
                }
                return .merge(effects)

            case .failure(let error):
                state.rawFooterLoadingState[targetFavIndex] = .failed(error)
            }
            return .none

        case .detail:
            return .none
        }
    }
    .binding(),
    detailReducer.pullback(
        state: \FavoritesState.detailState,
        action: /FavoritesAction.detail,
        environment: {
            .init(
                urlClient: $0.urlClient,
                fileClient: $0.fileClient,
                hapticClient: $0.hapticClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    )
)
