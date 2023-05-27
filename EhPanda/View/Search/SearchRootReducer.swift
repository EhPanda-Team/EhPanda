//
//  SearchRootReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import ComposableArchitecture

struct SearchRootReducer: ReducerProtocol {
    enum Route: Equatable {
        case search
        case filters
        case quickSearch
        case detail(String)
    }

    struct State: Equatable {
        @BindingState var route: Route?
        @BindingState var keyword = ""
        var historyGalleries = [Gallery]()

        var historyKeywords = [String]()
        var quickSearchWords = [QuickSearchWord]()

        var searchState = SearchReducer.State()
        var filtersState = FiltersReducer.State()
        var quickSearchState = QuickSearchReducer.State()
        @Heap var detailState: DetailReducer.State!

        init() {
            _detailState = .init(.init())
        }

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

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case setKeyword(String)
        case clearSubStates

        case syncHistoryKeywords
        case fetchDatabaseInfos
        case fetchDatabaseInfosDone(AppEnv)
        case appendHistoryKeyword(String)
        case removeHistoryKeyword(String)
        case fetchHistoryGalleries
        case fetchHistoryGalleriesDone([Gallery])

        case search(SearchReducer.Action)
        case filters(FiltersReducer.Action)
        case quickSearch(QuickSearchReducer.Action)
        case detail(DetailReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticsClient) private var hapticsClient

    var body: some ReducerProtocol<State, Action> {
        BindingReducer()

        Reduce { state, action in
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
                return databaseClient.updateHistoryKeywords(state.historyKeywords).fireAndForget()

            case .fetchDatabaseInfos:
                return databaseClient.fetchAppEnv().map(Action.fetchDatabaseInfosDone)

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
                return databaseClient.fetchHistoryGalleries(fetchLimit: 10).map(Action.fetchHistoryGalleriesDone)

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
            case: /Route.quickSearch,
            hapticsClient: hapticsClient
        )
        .haptics(
            unwrapping: \.route,
            case: /Route.filters,
            hapticsClient: hapticsClient
        )

        Scope(state: \.searchState, action: /Action.search, child: SearchReducer.init)
        Scope(state: \.filtersState, action: /Action.filters, child: FiltersReducer.init)
        Scope(state: \.quickSearchState, action: /Action.quickSearch, child: QuickSearchReducer.init)
        Scope(state: \.detailState, action: /Action.detail, child: DetailReducer.init)
    }
}
