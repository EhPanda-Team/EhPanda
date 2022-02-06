//
//  FiltersStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import ComposableArchitecture

struct FiltersState: Equatable {
    enum Route {
        case resetFilters
    }
    enum FocusedBound {
        case lower
        case upper
    }

    @BindableState var route: Route?
    @BindableState var filterRange: FilterRange = .search
    @BindableState var focusedBound: FocusedBound?
}

enum FiltersAction: BindableAction {
    case binding(BindingAction<FiltersState>)
    case setNavigation(FiltersState.Route?)
    case onResetFilterConfirmed
    case onTextFieldSubmitted
}

struct FiltersEnvironment {}

let filtersReducer = Reducer<FiltersState, FiltersAction, FiltersEnvironment> { state, action, _ in
    switch action {
    case .binding:
        return .none

    case .setNavigation(let route):
        state.route = route
        return .none

    case .onResetFilterConfirmed:
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
    }
}
.binding()
