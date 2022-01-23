//
//  HomeStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/05.
//

import SwiftUI
import Kingfisher
import UIImageColors
import ComposableArchitecture

struct HomeState: Equatable {
    enum Route: Equatable, Hashable {
        case detail(String)
        case misc(HomeMiscGridType)
        case section(HomeSectionType)
    }

    @BindableState var route: Route?
    @BindableState var cardPageIndex = 1
    @BindableState var currentCardID = ""
    var allowsCardHitTesting = true
    var rawCardColors = [String: [Color]]()
    var cardColors: [Color] {
        rawCardColors[currentCardID] ?? [.clear]
    }

    // Will be passed over from `appReducer`
    var filter = Filter()

    var popularGalleries = [Gallery]()
    var popularLoadingState: LoadingState = .idle
    var frontpageGalleries = [Gallery]()
    var frontpageLoadingState: LoadingState = .idle
    var toplistsGalleries = [Int: [Gallery]]()
    var toplistsLoadingState = [Int: LoadingState]()

    var frontpageState = FrontpageState()
    var toplistsState = ToplistsState()
    var popularState = PopularState()
    var watchedState = WatchedState()
    var historyState = HistoryState()
    var detailState = DetailState()

    mutating func setPopularGalleries(_ galleries: [Gallery]) {
        let sortedGalleries = galleries.sorted { lhs, rhs in
            lhs.title.count > rhs.title.count
        }
        var trimmedGalleries = Array(sortedGalleries.prefix(10))
            .removeDuplicates(by: \.trimmedTitle)
        if trimmedGalleries.count >= 6 {
            trimmedGalleries = Array(trimmedGalleries.prefix(6))
        }
        trimmedGalleries.shuffle()
        popularGalleries = trimmedGalleries
        currentCardID = trimmedGalleries[cardPageIndex].gid
    }
    mutating func setFrontpageGalleries(_ galleries: [Gallery]) {
        frontpageGalleries = Array(galleries.prefix(25))
            .removeDuplicates(by: \.trimmedTitle)
    }
}

enum HomeAction: BindableAction {
    case binding(BindingAction<HomeState>)
    case setNavigation(HomeState.Route?)
    case clearSubStates
    case setAllowsCardHitTesting(Bool)
    case analyzeImageColors(String, RetrieveImageResult)
    case analyzeImageColorsDone(String, UIImageColors?)

    case fetchAllGalleries
    case fetchAllToplistsGalleries
    case fetchPopularGalleries
    case fetchPopularGalleriesDone(Result<[Gallery], AppError>)
    case fetchFrontpageGalleries(Int? = nil)
    case fetchFrontpageGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)
    case fetchToplistsGalleries(Int, Int? = nil)
    case fetchToplistsGalleriesDone(Int, Result<(PageNumber, [Gallery]), AppError>)

    case frontpage(FrontpageAction)
    case toplists(ToplistsAction)
    case popular(PopularAction)
    case watched(WatchedAction)
    case history(HistoryAction)
    case detail(DetailAction)
}

struct HomeEnvironment {
    let urlClient: URLClient
    let fileClient: FileClient
    let imageClient: ImageClient
    let deviceClient: DeviceClient
    let hapticClient: HapticClient
    let libraryClient: LibraryClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
    let clipboardClient: ClipboardClient
    let uiApplicationClient: UIApplicationClient
}

let homeReducer = Reducer<HomeState, HomeAction, HomeEnvironment>.combine(
    .init { state, action, environment in
        switch action {
        case .binding(\.$route):
            return state.route == nil ? .init(value: .clearSubStates) : .none

        case .binding(\.$cardPageIndex):
            guard state.cardPageIndex < state.popularGalleries.count else { return .none }
            state.currentCardID = state.popularGalleries[state.cardPageIndex].gid
            state.allowsCardHitTesting = false
            return .init(value: .setAllowsCardHitTesting(true))
                .delay(for: .milliseconds(300), scheduler: DispatchQueue.main)
                .eraseToEffect()

        case .binding:
            return .none

        case .setNavigation(let route):
            state.route = route
            return route == nil ? .init(value: .clearSubStates) : .none

        case .clearSubStates:
            state.frontpageState = .init()
            state.toplistsState = .init()
            state.popularState = .init()
            state.watchedState = .init()
            state.historyState = .init()
            state.detailState = .init()
            return .merge(
                .init(value: .frontpage(.cancelFetching)),
                .init(value: .toplists(.cancelFetching)),
                .init(value: .popular(.cancelFetching)),
                .init(value: .watched(.cancelFetching)),
                .init(value: .detail(.cancelFetching))
            )

        case .setAllowsCardHitTesting(let isAllowed):
            state.allowsCardHitTesting = isAllowed
            return .none

        case .fetchAllGalleries:
            return .merge(
                .init(value: .fetchPopularGalleries),
                .init(value: .fetchFrontpageGalleries()),
                .init(value: .fetchAllToplistsGalleries)
            )

        case .fetchAllToplistsGalleries:
            return .merge(
                ToplistsType.allCases.map({ HomeAction.fetchToplistsGalleries($0.categoryIndex) })
                    .map(Effect<HomeAction, Never>.init)
            )

        case .fetchPopularGalleries:
            guard state.popularLoadingState != .loading else { return .none }
            state.popularLoadingState = .loading
            state.rawCardColors = [String: [Color]]()
            return PopularGalleriesRequest(filter: state.filter)
                .effect.map(HomeAction.fetchPopularGalleriesDone)

        case .fetchPopularGalleriesDone(let result):
            state.popularLoadingState = .idle
            switch result {
            case .success(let galleries):
                guard !galleries.isEmpty else {
                    state.popularLoadingState = .failed(.notFound)
                    return .none
                }
                state.setPopularGalleries(galleries)
                return environment.databaseClient.cacheGalleries(galleries).fireAndForget()
            case .failure(let error):
                state.popularLoadingState = .failed(error)
            }
            return .none

        case .fetchFrontpageGalleries(let pageNum):
            guard state.frontpageLoadingState != .loading else { return .none }
            state.frontpageLoadingState = .loading
            return FrontpageGalleriesRequest(filter: state.filter, pageNum: pageNum)
                .effect.map(HomeAction.fetchFrontpageGalleriesDone)

        case .fetchFrontpageGalleriesDone(let result):
            state.frontpageLoadingState = .idle
            switch result {
            case .success(let (_, galleries)):
                guard !galleries.isEmpty else {
                    state.frontpageLoadingState = .failed(.notFound)
                    return .none
                }
                state.setFrontpageGalleries(galleries)
                return environment.databaseClient.cacheGalleries(galleries).fireAndForget()
            case .failure(let error):
                state.frontpageLoadingState = .failed(error)
            }
            return .none

        case .fetchToplistsGalleries(let index, let pageNum):
            guard state.toplistsLoadingState[index] != .loading else { return .none }
            state.toplistsLoadingState[index] = .loading
            return ToplistsGalleriesRequest(catIndex: index, pageNum: pageNum)
                .effect.map({ HomeAction.fetchToplistsGalleriesDone(index, $0) })

        case .fetchToplistsGalleriesDone(let index, let result):
            state.toplistsLoadingState[index] = .idle
            switch result {
            case .success(let (_, galleries)):
                guard !galleries.isEmpty else {
                    state.toplistsLoadingState[index] = .failed(.notFound)
                    return .none
                }
                state.toplistsGalleries[index] = galleries
                return environment.databaseClient.cacheGalleries(galleries).fireAndForget()
            case .failure(let error):
                state.toplistsLoadingState[index] = .failed(error)
            }
            return .none

        case .analyzeImageColors(let gid, let result):
            guard !state.rawCardColors.keys.contains(gid) else { return .none }
            return environment.libraryClient.analyzeImageColors(result.image)
                .map({ HomeAction.analyzeImageColorsDone(gid, $0) })

        case .analyzeImageColorsDone(let gid, let colors):
            if let colors = colors {
                state.rawCardColors[gid] = [
                    colors.primary, colors.secondary,
                    colors.detail, colors.background
                ]
                .map(Color.init)
            }
            return .none

        case .frontpage:
            return .none

        case .toplists:
            return .none

        case .popular:
            return .none

        case .watched:
            return .none

        case .history:
            return .none

        case .detail:
            return .none
        }
    }
    .binding(),
    frontpageReducer.pullback(
        state: \.frontpageState,
        action: /HomeAction.frontpage,
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
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    ),
    toplistsReducer.pullback(
        state: \.toplistsState,
        action: /HomeAction.toplists,
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
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    ),
    popularReducer.pullback(
        state: \.popularState,
        action: /HomeAction.popular,
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
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    ),
    watchedReducer.pullback(
        state: \.watchedState,
        action: /HomeAction.watched,
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
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    ),
    historyReducer.pullback(
        state: \.historyState,
        action: /HomeAction.history,
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
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    ),
    detailReducer.pullback(
        state: \.detailState,
        action: /HomeAction.detail,
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
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    )
)
