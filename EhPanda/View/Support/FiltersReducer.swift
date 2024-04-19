//
//  FiltersReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import ComposableArchitecture

struct FiltersReducer: Reducer {
    enum Route {
        case resetFilters
    }

    enum FocusedBound {
        case lower
        case upper
    }

    struct State: Equatable {
        @BindingState var route: Route?
        @BindingState var filterRange: FilterRange = .search
        @BindingState var focusedBound: FocusedBound?

        @BindingState var searchFilter = Filter()
        @BindingState var globalFilter = Filter()
        @BindingState var watchedFilter = Filter()
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case onTextFieldSubmitted

        case syncFilter(FilterRange)
        case resetFilters
        case fetchFilters
        case fetchFiltersDone(AppEnv)
    }

    @Dependency(\.databaseClient) private var databaseClient

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding(\.$searchFilter):
                state.searchFilter.fixInvalidData()
                return .send(.syncFilter(.search))

            case .binding(\.$globalFilter):
                state.globalFilter.fixInvalidData()
                return .send(.syncFilter(.global))

            case .binding(\.$watchedFilter):
                state.watchedFilter.fixInvalidData()
                return .send(.syncFilter(.watched))

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
                return .run { _ in
                    await databaseClient.updateFilter(filter, range: range)
                }

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
