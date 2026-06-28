import ComposableArchitecture
import AppModels
import SwiftUINavigationExt
import HapticsClient
import DatabaseClient
import NetworkingFeature
import FiltersFeature
import QuickSearchFeature
import ComposableArchitectureExt

@Reducer
public struct DetailSearchReducer: Sendable {
    @dynamicMemberLookup @CasePathable
    public enum Route: Equatable, Sendable {
        case filters(EquatableVoid = .unique)
        case quickSearch(EquatableVoid = .unique)
        case detail(String)
    }

    private enum CancelID: CaseIterable {
        case fetchGalleries, fetchMoreGalleries
    }

    @ObservableState
    public struct State: Equatable {
        public var route: Route?
        public var keyword = ""
        public var lastKeyword = ""

        public var galleries = [Gallery]()
        public var pageNumber = PageNumber()
        public var loadingState: LoadingState = .idle
        public var footerLoadingState: LoadingState = .idle

        public var detailState: Heap<DetailReducer.State?>
        public var filtersState = FiltersReducer.State()
        public var quickDetailSearchState = QuickSearchReducer.State()

        public init() {
            detailState = .init(.init())
        }

        mutating func insertGalleries(_ galleries: [Gallery]) {
            galleries.forEach { gallery in
                if !self.galleries.contains(gallery) {
                    self.galleries.append(gallery)
                }
            }
        }
    }

    public enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case clearSubStates

        case teardown
        case fetchGalleries(String? = nil)
        case fetchGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)
        case fetchMoreGalleries
        case fetchMoreGalleriesDone(Result<(PageNumber, [Gallery]), AppError>)

        case detail(DetailReducer.Action)
        case filters(FiltersReducer.Action)
        case quickSearch(QuickSearchReducer.Action)
    }

    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticsClient) private var hapticsClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.route) { _, state in
                state.route == nil ? .send(.clearSubStates) : .none
            }
            .onChange(of: \.keyword) { _, state in
                if !state.keyword.isEmpty {
                    state.lastKeyword = state.keyword
                }
                return .none
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return route == nil ? .send(.clearSubStates) : .none

            case .clearSubStates:
                state.detailState.wrappedValue = .init()
                state.filtersState = .init()
                state.quickDetailSearchState = .init()
                return .merge(
                    .send(.detail(.teardown)),
                    .send(.quickSearch(.teardown))
                )

            case .teardown:
                return .merge(CancelID.allCases.map(Effect.cancel(id:)))

            case .fetchGalleries(let keyword):
                guard state.loadingState != .loading else { return .none }
                if let keyword = keyword {
                    state.keyword = keyword
                    state.lastKeyword = keyword
                }
                state.loadingState = .loading
                state.pageNumber.resetPages()
                let filter = databaseClient.fetchFilterSynchronously(range: .search)
                return .run { [lastKeyword = state.lastKeyword] send in
                    let response = await SearchGalleriesRequest(keyword: lastKeyword, filter: filter).response()
                    await send(.fetchGalleriesDone(response.map { ($0.pageNumber, $0.galleries) }))
                }
                .cancellable(id: CancelID.fetchGalleries)

            case .fetchGalleriesDone(let result):
                state.loadingState = .idle
                switch result {
                case .success(let (pageNumber, galleries)):
                    guard !galleries.isEmpty else {
                        state.loadingState = .failed(.notFound)
                        guard pageNumber.hasNextPage() else { return .none }
                        return .send(.fetchMoreGalleries)
                    }
                    state.pageNumber = pageNumber
                    state.galleries = galleries
                    return .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                case .failure(let error):
                    state.loadingState = .failed(error)
                }
                return .none

            case .fetchMoreGalleries:
                let pageNumber = state.pageNumber
                guard pageNumber.hasNextPage(),
                      state.footerLoadingState != .loading,
                      let lastID = state.galleries.last?.id
                else { return .none }
                state.footerLoadingState = .loading
                let filter = databaseClient.fetchFilterSynchronously(range: .search)
                return .run { [lastKeyword = state.lastKeyword] send in
                    let response = await MoreSearchGalleriesRequest(
                        keyword: lastKeyword, filter: filter, lastID: lastID
                    )
                    .response()
                    await send(.fetchMoreGalleriesDone(response.map { ($0.pageNumber, $0.galleries) }))
                }
                .cancellable(id: CancelID.fetchMoreGalleries)

            case .fetchMoreGalleriesDone(let result):
                state.footerLoadingState = .idle
                switch result {
                case .success(let (pageNumber, galleries)):
                    state.pageNumber = pageNumber
                    state.insertGalleries(galleries)

                    var effects: [Effect<Action>] = [
                        .run(operation: { _ in await databaseClient.cacheGalleries(galleries) })
                    ]
                    if galleries.isEmpty, pageNumber.hasNextPage() {
                        effects.append(.send(.fetchMoreGalleries))
                    } else if !galleries.isEmpty {
                        state.loadingState = .idle
                    }
                    return .merge(effects)

                case .failure(let error):
                    state.footerLoadingState = .failed(error)
                }
                return .none

            case .detail:
                return .none

            case .filters:
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
        .haptics(
            unwrapping: \.route,
            case: \.filters,
            hapticsClient: hapticsClient
        )

        Scope(state: \.filtersState, action: \.filters, child: FiltersReducer.init)
        Scope(state: \.quickDetailSearchState, action: \.quickSearch, child: QuickSearchReducer.init)
    }
}
