//
//  SearchStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import ComposableArchitecture

struct SearchState: Equatable {
    enum Route: Equatable {
        case request
        case quickSearch
        case detail(String)
    }

    @BindableState var route: Route?
    @BindableState var keyword = ""
    var historyGalleries = [Gallery]()

    var historyKeywords = [String]()
    var quickSearchWords = [QuickSearchWord]()

    var searchRequestState = SearchRequestState()
    var quickSearchState = QuickSearchState()
    var detailState = DetailState()

    mutating func appendHistoryKeywords(_ keywords: [String]) {
        guard !keywords.isEmpty else { return }
        var historyKeywords = historyKeywords

        keywords.forEach { keyword in
            guard !keyword.isEmpty else { return }
            if let index = historyKeywords.firstIndex(where: {
                $0.caseInsensitiveEqualsTo(keyword)
            }) {
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

enum SearchAction: BindableAction {
    case binding(BindingAction<SearchState>)
    case setNavigation(SearchState.Route?)
    case setKeyword(String)
    case clearSubStates
    case onFiltersButtonTapped

    case syncHistoryKeywords
    case fetchDatabaseInfos
    case fetchDatabaseInfosDone(AppEnv)
    case appendHistoryKeyword(String)
    case removeHistoryKeyword(String)
    case fetchHistoryGalleries
    case fetchHistoryGalleriesDone([Gallery])

    case searchRequest(SearchRequestAction)
    case quickSearch(QuickSearchAction)
    case detail(DetailAction)
}

struct SearchEnvironment {
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

let searchReducer = Reducer<SearchState, SearchAction, SearchEnvironment>.combine(
    .init { state, action, environment in
        switch action {
        case .binding(\.$route):
            return state.route == nil
            ? .merge(
                .init(value: .clearSubStates),
                .init(value: .fetchDatabaseInfos)
            )
            : .none

        case .binding:
            return .none

        case .setNavigation(let route):
            state.route = route
            return route == nil
            ? .merge(
                .init(value: .clearSubStates),
                .init(value: .fetchDatabaseInfos)
            )
            : .none

        case .setKeyword(let keyword):
            state.keyword = keyword
            return .none

        case .clearSubStates:
            state.searchRequestState = .init()
            state.quickSearchState = .init()
            state.detailState = .init()
            return .merge(
                .init(value: .searchRequest(.teardown)),
                .init(value: .quickSearch(.teardown)),
                .init(value: .detail(.teardown))
            )

        case .onFiltersButtonTapped:
            return .none

        case .syncHistoryKeywords:
            return environment.databaseClient.updateHistoryKeywords(state.historyKeywords).fireAndForget()

        case .fetchDatabaseInfos:
            return environment.databaseClient.fetchAppEnv().map(SearchAction.fetchDatabaseInfosDone)

        case .fetchDatabaseInfosDone(let appEnv):
            state.historyKeywords = appEnv.historyKeywords
            state.quickSearchWords = appEnv.quickSearchWords
            return .none

        case .appendHistoryKeyword(let keyword):
            state.appendHistoryKeywords([keyword])
            return .init(value: .syncHistoryKeywords)

        case .removeHistoryKeyword(let keyword):
            state.removeHistoryKeyword(keyword)
            return .init(value: .syncHistoryKeywords)

        case .fetchHistoryGalleries:
            return environment.databaseClient
                .fetchHistoryGalleries(fetchLimit: 10).map(SearchAction.fetchHistoryGalleriesDone)

        case .fetchHistoryGalleriesDone(let galleries):
            state.historyGalleries = Array(galleries.prefix(min(galleries.count, 10)))
            return .none

        case .searchRequest(.fetchGalleries(_, let keyword)):
            if let keyword = keyword {
                state.appendHistoryKeywords([keyword])
            } else {
                state.appendHistoryKeywords([state.searchRequestState.lastKeyword])
            }
            return .init(value: .syncHistoryKeywords)

        case .searchRequest:
            return .none

        case .quickSearch:
            return .none

        case .detail:
            return .none
        }
    }
    .haptics(
        unwrapping: \.route,
        case: /SearchState.Route.quickSearch,
        hapticClient: \.hapticClient
    )
    .binding(),
    searchRequestReducer.pullback(
        state: \.searchRequestState,
        action: /SearchAction.searchRequest,
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
        action: /SearchAction.quickSearch,
        environment: {
            .init(
                databaseClient: $0.databaseClient
            )
        }
    ),
    detailReducer.pullback(
        state: \.detailState,
        action: /SearchAction.detail,
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
    )
)
