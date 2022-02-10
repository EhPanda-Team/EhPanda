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
        case quickSearch
        case detail(String)
    }

    init() {
        _detailState = .init(.init())
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

    @Heap var detailState: DetailState!
    var quickSearchState = QuickSearchState()

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
    case onNotLoginViewButtonTapped

    case performJumpPage
    case presentJumpPageAlert
    case setJumpPageAlertFocused(Bool)

    case fetchGalleries(Int? = nil, String? = nil, FavoritesSortOrder? = nil)
    case fetchGalleriesDone(Int, Result<(PageNumber, FavoritesSortOrder?, [Gallery]), AppError>)
    case fetchMoreGalleries
    case fetchMoreGalleriesDone(Int, Result<(PageNumber, FavoritesSortOrder?, [Gallery]), AppError>)

    case detail(DetailAction)
    case quickSearch(QuickSearchAction)
}

// MARK: Environment
struct FavoritesEnvironment {
    let urlClient: URLClient
    let fileClient: FileClient
    let imageClient: ImageClient
    let deviceClient: DeviceClient
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
    let clipboardClient: ClipboardClient
    let appDelegateClient: AppDelegateClient
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
            return .init(value: .detail(.teardown))

        case .onNotLoginViewButtonTapped:
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

        case .fetchGalleries(let pageNum, let keyword, let sortOrder):
            guard state.loadingState != .loading else { return .none }
            state.rawLoadingState[state.index] = .loading
            if let keyword = keyword {
                state.keyword = keyword
            }
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
                    state.rawLoadingState[targetFavIndex] = .failed(.notFound)
                    guard pageNumber.current < pageNumber.maximum else { return .none }
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
            let pageNumber = state.pageNumber ?? .init()
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
        case: /FavoritesState.Route.quickSearch,
        hapticClient: \.hapticClient
    )
    .binding(),
    detailReducer.pullback(
        state: \FavoritesState.detailState,
        action: /FavoritesAction.detail,
        environment: {
            .init(
                urlClient: $0.urlClient,
                fileClient: $0.fileClient,
                imageClient: $0.imageClient,
                deviceClient: $0.deviceClient,
                hapticClient: $0.hapticClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                appDelegateClient: $0.appDelegateClient,
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    ),
    quickSearchReducer.pullback(
        state: \.quickSearchState,
        action: /FavoritesAction.quickSearch,
        environment: {
            .init(
                databaseClient: $0.databaseClient
            )
        }
    )
)
