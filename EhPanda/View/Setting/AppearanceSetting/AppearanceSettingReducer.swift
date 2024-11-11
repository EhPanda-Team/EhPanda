//
//  AppearanceSettingReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/03.
//

import ComposableArchitecture

@Reducer
struct AppearanceSettingReducer {
    @CasePathable
    enum Route {
        case appIcon
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
    }

    var body: some Reducer<State, Action> {
        BindingReducer()

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return .none
            }
        }
    }
}
