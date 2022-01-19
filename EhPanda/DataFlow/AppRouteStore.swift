//
//  AppRouteStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/08.
//

import ComposableArchitecture

struct AppRouteState: Equatable {
    enum Route: Equatable {
        case filters
        case newDawn(Greeting)
    }

    @BindableState var route: Route?

    var filtersState = FiltersState()
}

enum AppRouteAction: BindableAction {
    case binding(BindingAction<AppRouteState>)
    case setNavigation(AppRouteState.Route?)

    case fetchGreetingDone(Result<Greeting, AppError>)

    case filters(FiltersAction)
}

struct AppRouteEnvironment {}

let appRouteReducer = Reducer<AppRouteState, AppRouteAction, AppRouteEnvironment>.combine(
    .init { state, action, _ in
        switch action {
        case .binding:
            return .none

        case .setNavigation(let route):
            state.route = route
            return .none

        case .fetchGreetingDone(let result):
            if case .success(let greeting) = result, !greeting.gainedNothing {
                return .init(value: .setNavigation(.newDawn(greeting)))
            }
            return .none

        case .filters:
            return .none
        }
    }
    .binding(),
    filtersReducer.pullback(
        state: \.filtersState,
        action: /AppRouteAction.filters,
        environment: { _ in
            .init()
        }
    )
)
