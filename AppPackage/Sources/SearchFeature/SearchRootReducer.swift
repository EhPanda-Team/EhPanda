import ComposableArchitecture
import AppModels
import AppTools
import SwiftUINavigationExt
import HapticsClient
import DatabaseClient
import FiltersFeature
import QuickSearchFeature
import DetailFeature
import ComposableArchitectureExt

@Reducer
public struct SearchRootReducer: Sendable {
    @CasePathable
    public enum Route: Equatable, Sendable {
        case search
        case detail(String)
    }

    @Reducer
    public enum Destination {
        case filters(FiltersReducer)
        case quickSearch(QuickSearchReducer)
    }

    @ObservableState
    public struct State: Equatable {
        public var route: Route?
        @Presents public var destination: Destination.State?
        public var keyword = ""
        public var historyGalleries = [Gallery]()

        public var historyKeywords = [String]()
        public var quickSearchWords = [QuickSearchWord]()

        public var searchState = SearchReducer.State()
        public var detailState: Heap<DetailReducer.State?>

        public init() {
            detailState = .init(.init())
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

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case setKeyword(String)
        case clearSubStates
        case filtersButtonTapped
        case quickSearchButtonTapped
        case destination(PresentationAction<Destination.Action>)

        case syncHistoryKeywords
        case fetchDatabaseInfos
        case fetchDatabaseInfosDone(AppEnv)
        case appendHistoryKeyword(String)
        case removeHistoryKeyword(String)
        case fetchHistoryGalleries
        case fetchHistoryGalleriesDone([Gallery])

        case search(SearchReducer.Action)
        case detail(DetailReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticsClient) private var hapticsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.route) { _, state in
                state.route == nil
                    ? .merge(
                        .send(.clearSubStates),
                        .send(.fetchDatabaseInfos)
                    )
                    : .none
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil
                    ? .merge(
                        .send(.clearSubStates),
                        .send(.fetchDatabaseInfos)
                    )
                    : .none

            case .setKeyword(let keyword):
                state.keyword = keyword
                return .none

            case .clearSubStates:
                state.searchState = .init()
                state.detailState.wrappedValue = .init()
                return .merge(
                    .send(.search(.teardown)),
                    .send(.detail(.teardown))
                )

            case .filtersButtonTapped:
                state.destination = .filters(FiltersReducer.State())
                return .none

            case .quickSearchButtonTapped:
                state.destination = .quickSearch(QuickSearchReducer.State())
                return .none

            case .destination:
                return .none

            case .syncHistoryKeywords:
                return .run { [historyKeywords = state.historyKeywords] _ in
                    await databaseClient.updateHistoryKeywords(historyKeywords)
                }

            case .fetchDatabaseInfos:
                return .run { send in
                    let appEnv = await databaseClient.fetchAppEnv()
                    await send(.fetchDatabaseInfosDone(appEnv))
                }

            case .fetchDatabaseInfosDone(let appEnv):
                state.historyKeywords = appEnv.historyKeywords
                state.quickSearchWords = appEnv.quickSearchWords
                return .none

            case .appendHistoryKeyword(let keyword):
                state.appendHistoryKeywords([keyword])
                return .send(.syncHistoryKeywords)

            case .removeHistoryKeyword(let keyword):
                state.removeHistoryKeyword(keyword)
                return .send(.syncHistoryKeywords)

            case .fetchHistoryGalleries:
                return .run { send in
                    let historyGalleries = await databaseClient.fetchHistoryGalleries(fetchLimit: 10)
                    await send(.fetchHistoryGalleriesDone(historyGalleries))
                }

            case .fetchHistoryGalleriesDone(let galleries):
                state.historyGalleries = Array(galleries.prefix(min(galleries.count, 10)))
                return .none

            case .search(.fetchGalleries(let keyword)):
                if let keyword = keyword {
                    state.appendHistoryKeywords([keyword])
                } else {
                    state.appendHistoryKeywords([state.searchState.lastKeyword])
                }
                return .send(.syncHistoryKeywords)

            case .search:
                return .none

            case .detail:
                return .none
            }
        }
        .haptics(
            unwrapping: \.destination,
            case: \.quickSearch,
            hapticsClient: hapticsClient
        )
        .haptics(
            unwrapping: \.destination,
            case: \.filters,
            hapticsClient: hapticsClient
        )
        .ifLet(\.$destination, action: \.destination)

        Scope(state: \.searchState, action: \.search, child: SearchReducer.init)
        Scope(state: \.detailState.wrappedValue!, action: \.detail, child: DetailReducer.init)
    }
}

extension SearchRootReducer.Destination.State: Equatable, Sendable {}
