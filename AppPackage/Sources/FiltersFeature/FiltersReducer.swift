import ComposableArchitecture
import AppModels
import DatabaseClient

@Reducer
public struct FiltersReducer: Sendable {
    @CasePathable
    public enum Route: Sendable {
        case resetFilters
    }

    public enum FocusedBound {
        case lower
        case upper
    }

    @ObservableState
    public struct State: Equatable {
        public var route: Route?
        public var filterRange: FilterRange = .search
        public var focusedBound: FocusedBound?

        public var searchFilter = Filter()
        public var globalFilter = Filter()
        public var watchedFilter = Filter()

        public init() {}
    }

    public enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case onTextFieldSubmitted

        case syncFilter(FilterRange)
        case resetFilters
        case fetchFilters
        case fetchFiltersDone(AppEnv)
    }

    @Dependency(\.databaseClient) private var databaseClient

    public init() {}

    public var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.searchFilter) { _, state in
                state.searchFilter.fixInvalidData()
                return .send(.syncFilter(.search))
            }
            .onChange(of: \.globalFilter) { _, state in
                state.globalFilter.fixInvalidData()
                return .send(.syncFilter(.global))
            }
            .onChange(of: \.watchedFilter) { _, state in
                state.watchedFilter.fixInvalidData()
                return .send(.syncFilter(.watched))
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return .none

            case .onTextFieldSubmitted:
                switch state.focusedBound {
                case .lower:
                    state.focusedBound = .upper
                case .upper:
                    state.focusedBound = nil
                default:
                    break
                }
                return .none

            case .syncFilter(let range):
                let filter: Filter
                switch range {
                case .search:
                    filter = state.searchFilter
                case .global:
                    filter = state.globalFilter
                case .watched:
                    filter = state.watchedFilter
                }
                return .run(operation: { _ in await databaseClient.updateFilter(filter, range: range) })

            case .resetFilters:
                switch state.filterRange {
                case .search:
                    state.searchFilter = .init()
                    return .send(.syncFilter(.search))
                case .global:
                    state.globalFilter = .init()
                    return .send(.syncFilter(.global))
                case .watched:
                    state.watchedFilter = .init()
                    return .send(.syncFilter(.watched))
                }

            case .fetchFilters:
                return .run { send in
                    let appEnv = await databaseClient.fetchAppEnv()
                    await send(.fetchFiltersDone(appEnv))
                }

            case .fetchFiltersDone(let appEnv):
                state.searchFilter = appEnv.searchFilter
                state.globalFilter = appEnv.globalFilter
                state.watchedFilter = appEnv.watchedFilter
                return .none
            }
        }
    }
}
