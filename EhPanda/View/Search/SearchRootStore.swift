//
//  SearchRootStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import ComposableArchitecture

struct SearchRootState: Equatable {
    enum Route: Equatable {
        case search
        case filters
        case quickSearch
        case detail(String)
    }

    init() {
        _detailState = .init(.init())
    }

    @BindingState var route: Route?
    @BindingState var keyword = ""
    var historyGalleries = [Gallery]()

    var historyKeywords = [String]()
    var quickSearchWords = [QuickSearchWord]()

    var searchState = SearchState()
    var filtersState = FiltersState()
    var quickSearchState = QuickSearchState()
    @Heap var detailState: DetailState!

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

enum SearchRootAction: BindableAction {
    case binding(BindingAction<SearchRootState>)
    case setNavigation(SearchRootState.Route?)
    case setKeyword(String)
    case clearSubStates

    case syncHistoryKeywords
    case fetchDatabaseInfos
    case fetchDatabaseInfosDone(AppEnv)
    case appendHistoryKeyword(String)
    case removeHistoryKeyword(String)
    case fetchHistoryGalleries
    case fetchHistoryGalleriesDone([Gallery])

    case search(SearchAction)
    case filters(FiltersAction)
    case quickSearch(QuickSearchAction)
    case detail(DetailAction)
}

struct SearchRootEnvironment {
    let urlClient: URLClient
    let fileClient: FileClient
    let imageClient: ImageClient
    let deviceClient: DeviceClient
    let hapticsClient: HapticsClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
    let clipboardClient: ClipboardClient
    let appDelegateClient: AppDelegateClient
    let uiApplicationClient: UIApplicationClient
}

let searchRootReducer = Reducer<SearchRootState, SearchRootAction, SearchRootEnvironment>.combine(
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
            state.searchState = .init()
            state.detailState = .init()
            state.filtersState = .init()
            state.quickSearchState = .init()
            return .merge(
                .init(value: .search(.teardown)),
                .init(value: .quickSearch(.teardown)),
                .init(value: .detail(.teardown))
            )

        case .syncHistoryKeywords:
            return environment.databaseClient.updateHistoryKeywords(state.historyKeywords).fireAndForget()

        case .fetchDatabaseInfos:
            return environment.databaseClient.fetchAppEnv().map(SearchRootAction.fetchDatabaseInfosDone)

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
                .fetchHistoryGalleries(fetchLimit: 10).map(SearchRootAction.fetchHistoryGalleriesDone)

        case .fetchHistoryGalleriesDone(let galleries):
            state.historyGalleries = Array(galleries.prefix(min(galleries.count, 10)))
            return .none

        case .search(.fetchGalleries(let keyword)):
            if let keyword = keyword {
                state.appendHistoryKeywords([keyword])
            } else {
                state.appendHistoryKeywords([state.searchState.lastKeyword])
            }
            return .init(value: .syncHistoryKeywords)

        case .search:
            return .none

        case .filters:
            return .none

        case .quickSearch:
            return .none

        case .detail:
            return .none
        }
    }
    .haptics(
        unwrapping: \.route,
        case: /SearchRootState.Route.quickSearch,
        hapticsClient: \.hapticsClient
    )
    .haptics(
        unwrapping: \.route,
        case: /SearchRootState.Route.filters,
        hapticsClient: \.hapticsClient
    )
    .binding(),
    searchReducer.pullback(
        state: \.searchState,
        action: /SearchRootAction.search,
        environment: {
            .init(
                urlClient: $0.urlClient,
                fileClient: $0.fileClient,
                imageClient: $0.imageClient,
                deviceClient: $0.deviceClient,
                hapticsClient: $0.hapticsClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                appDelegateClient: $0.appDelegateClient,
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    ),
    filtersReducer.pullback(
        state: \.filtersState,
        action: /SearchRootAction.filters,
        environment: {
            .init(
                databaseClient: $0.databaseClient
            )
        }
    ),
    quickSearchReducer.pullback(
        state: \.quickSearchState,
        action: /SearchRootAction.quickSearch,
        environment: {
            .init(
                databaseClient: $0.databaseClient
            )
        }
    ),
    detailReducer.pullback(
        state: \.detailState,
        action: /SearchRootAction.detail,
        environment: {
            .init(
                urlClient: $0.urlClient,
                fileClient: $0.fileClient,
                imageClient: $0.imageClient,
                deviceClient: $0.deviceClient,
                hapticsClient: $0.hapticsClient,
                cookiesClient: $0.cookiesClient,
                databaseClient: $0.databaseClient,
                clipboardClient: $0.clipboardClient,
                appDelegateClient: $0.appDelegateClient,
                uiApplicationClient: $0.uiApplicationClient
            )
        }
    )
)
