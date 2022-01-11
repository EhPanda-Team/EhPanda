//
//  SearchStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import ComposableArchitecture

struct SearchState: Equatable {
    // AppEnvStorage
    var historyKeywords = [String]()

    @BindableState var route: SearchViewRoute?
    @BindableState var keyword = ""
    var historyGalleries = [Gallery]()

    var searchReqeustState = SearchRequestState()
    var detailState = DetailState()

    mutating func appendHistoryKeywords(_ keywords: [String]) {
        guard !keywords.isEmpty else { return }
        var historyKeywords = historyKeywords

        keywords.forEach { keyword in
            guard !keyword.isEmpty else { return }
            if let index = historyKeywords.firstIndex(of: keyword) {
                if historyKeywords.last != keyword {
                    historyKeywords.remove(at: index)
                    historyKeywords.append(keyword)
                }
            } else {
                historyKeywords.append(keyword)
                let overflow = historyKeywords.count - 20
                if overflow > 0 {
                    historyKeywords = Array(
                        historyKeywords.dropFirst(overflow)
                    )
                }
            }
        }
        self.historyKeywords = historyKeywords
    }
    mutating func removeHistoryKeyword(_ keyword: String) {
        historyKeywords = historyKeywords.filter { $0 != keyword }
    }
}

struct SearchRequestState: Equatable {
    var route: SearchRequestViewRoute?
    @BindableState var keyword = ""
    var lastKeyword = ""

    @BindableState var jumpPageIndex = ""
    @BindableState var jumpPageAlertFocused = false
    @BindableState var jumpPageAlertPresented = false

    // Will be passed over from `appReducer`
    var filter = Filter()

    var galleries = [Gallery]()
    var pageNumber = PageNumber()
    var loadingState: LoadingState = .idle
    var footerLoadingState: LoadingState = .idle

    var detailState = DetailState()

    mutating func insertGalleries(_ galleries: [Gallery]) {
        galleries.forEach { gallery in
            if !self.galleries.contains(gallery) {
                self.galleries.append(gallery)
            }
        }
    }
}

enum SearchAction: BindableAction {
    case binding(BindingAction<SearchState>)
    case setNavigation(SearchViewRoute?)
    case clearSubStates
    case onFiltersButtonTapped
    case setKeyword(String)
    case syncHistoryKeywords
    case fetchHistoryKeywords
    case fetchHistoryKeywordsDone([String])
    case appendHistoryKeyword(String)
    case removeHistoryKeyword(String)
    case fetchHistoryGalleries
    case fetchHistoryGalleriesDone([Gallery])

    case searchRequest(SearchRequestAction)
    case detail(DetailAction)
}

enum SearchRequestAction: BindableAction {
    case binding(BindingAction<SearchRequestState>)
    case setNavigation(SearchRequestViewRoute?)
    case clearSubStates
    case onDisappear
    case onFiltersButtonTapped

    case performJumpPage
    case presentJumpPageAlert
    case setJumpPageAlertFocused(Bool)

    case fetchGalleries(Int? = nil, String? = nil)
    case fetchGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)
    case fetchMoreGalleries
    case fetchMoreGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)

    case detail(DetailAction)
}

struct SearchEnvironment {
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
}

struct SearchRequestEnvironment {
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
}

let searchReducer = Reducer<SearchState, SearchAction, SearchEnvironment>.combine(
    .init { state, action, environment in
        switch action {
        case .binding(\.$route):
            return state.route == nil ? .init(value: .clearSubStates) : .none

        case .binding:
            return .none

        case .setNavigation(let route):
            state.route = route
            return route == nil ? .init(value: .clearSubStates) : .none

        case .clearSubStates:
            state.searchReqeustState = .init()
            state.detailState = .init()
            return .none

        case .onFiltersButtonTapped:
            return .none

        case .setKeyword(let keyword):
            state.keyword = keyword
            return .none

        case .syncHistoryKeywords:
            return environment.databaseClient.updateHistoryKeywords(state.historyKeywords).fireAndForget()

        case .fetchHistoryKeywords:
            return environment.databaseClient.fetchHistoryKeywords().map(SearchAction.fetchHistoryKeywordsDone)

        case .fetchHistoryKeywordsDone(let historyKeywords):
            state.historyKeywords = historyKeywords
            return .none

        case .appendHistoryKeyword(let keyword):
            state.appendHistoryKeywords([keyword])
            return .init(value: .syncHistoryKeywords)

        case .removeHistoryKeyword(let keyword):
            state.removeHistoryKeyword(keyword)
            return .init(value: .syncHistoryKeywords)

        case .fetchHistoryGalleries:
            return environment.databaseClient.fetchHistoryGalleries(10).map(SearchAction.fetchHistoryGalleriesDone)

        case .fetchHistoryGalleriesDone(let galleries):
            state.historyGalleries = Array(galleries.prefix(min(galleries.count, 10)))
            return .none

        case .searchRequest(.fetchGalleries(_, let keyword)):
            if let keyword = keyword {
                state.appendHistoryKeywords([keyword])
            } else {
                state.appendHistoryKeywords([state.searchReqeustState.lastKeyword])
            }
            return .init(value: .syncHistoryKeywords)

        case .searchRequest:
            return .none

        case .detail:
            return .none
        }
    }
    .binding(),
    searchRequestReducer.pullback(
        state: \.searchReqeustState,
        action: /SearchAction.searchRequest,
        environment: {
            .init(
                hapticClient: $0.hapticClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient
            )
        }
    ),
    detailReducer.pullback(
        state: \.detailState,
        action: /SearchAction.detail,
        environment: {
            .init(
                hapticClient: $0.hapticClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient
            )
        }
    )
)

let searchRequestReducer = Reducer<SearchRequestState, SearchRequestAction, SearchRequestEnvironment>.combine(
    .init { state, action, environment in
        switch action {
        case .binding(\.$keyword):
            if !state.keyword.isEmpty {
                state.lastKeyword = state.keyword
            }
            return .none

        case .binding:
            return .none

        case .setNavigation(let route):
            state.route = route
            return route == nil ? .init(value: .clearSubStates) : .none

        case .clearSubStates:
            state.detailState = .init()
            return .none

        case .onDisappear:
            state.jumpPageAlertPresented = false
            state.jumpPageAlertFocused = false
            return .none

        case .onFiltersButtonTapped:
            return .none

        case .performJumpPage:
            guard let index = Int(state.jumpPageIndex), index > 0, index <= state.pageNumber.maximum + 1 else {
                return environment.hapticClient.generateNotificationFeedback(.error).fireAndForget()
            }
            return .init(value: .fetchGalleries(index - 1))

        case .presentJumpPageAlert:
            state.jumpPageAlertPresented = true
            return environment.hapticClient.generateFeedback(.light).fireAndForget()

        case .setJumpPageAlertFocused(let isFocused):
            state.jumpPageAlertFocused = isFocused
            return .none

        case .fetchGalleries(let pageNum, let keyword):
            guard state.loadingState != .loading else { return .none }
            if let keyword = keyword {
                state.lastKeyword = keyword
            }
            state.loadingState = .loading
            state.pageNumber.current = 0
            return SearchGalleriesRequest(keyword: keyword ?? state.lastKeyword, filter: state.filter, pageNum: pageNum)
                .effect.map(SearchRequestAction.fetchGalleriesDone)

        case .fetchGalleriesDone(let result):
            state.loadingState = .idle
            switch result {
            case .success(let (pageNumber, galleries)):
                guard !galleries.isEmpty else {
                    guard pageNumber.current < pageNumber.maximum else {
                        state.loadingState = .failed(.notFound)
                        return .none
                    }
                    return .init(value: .fetchMoreGalleries)
                }
                state.pageNumber = pageNumber
                state.galleries = galleries
                return environment.databaseClient.cacheGalleries(galleries).fireAndForget()
            case .failure(let error):
                state.loadingState = .failed(error)
            }
            return .none

        case .fetchMoreGalleries:
            let pageNumber = state.pageNumber
            guard pageNumber.current + 1 <= pageNumber.maximum,
                  state.footerLoadingState != .loading,
                  let lastID = state.galleries.last?.id
            else { return .none }
            state.footerLoadingState = .loading
            let pageNum = pageNumber.current + 1
            return MoreSearchGalleriesRequest(
                keyword: state.lastKeyword, filter: state.filter, lastID: lastID, pageNum: pageNum
            )
            .effect.map(SearchRequestAction.fetchMoreGalleriesDone)

        case .fetchMoreGalleriesDone(let result):
            state.footerLoadingState = .idle
            switch result {
            case .success(let (pageNumber, galleries)):
                state.pageNumber = pageNumber
                state.insertGalleries(galleries)

                var effects: [Effect<SearchRequestAction, Never>] = [
                    environment.databaseClient.cacheGalleries(galleries).fireAndForget()
                ]
                if galleries.isEmpty, pageNumber.current < pageNumber.maximum {
                    effects.append(.init(value: .fetchMoreGalleries))
                }
                return .merge(effects)

            case .failure(let error):
                state.footerLoadingState = .failed(error)
            }
            return .none

        case .detail:
            return .none
        }
    }
    .binding(),
    detailReducer.pullback(
        state: \.detailState,
        action: /SearchRequestAction.detail,
        environment: {
            .init(
                hapticClient: $0.hapticClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient
            )
        }
    )
)
