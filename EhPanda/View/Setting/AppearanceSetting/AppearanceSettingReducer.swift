//
//  AppearanceSettingReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/03.
//

import ComposableArchitecture

struct AppearanceSettingReducer: ReducerProtocol {
    enum Route {
        case appIcon
    }

    struct State: Equatable {
        @BindingState var route: Route?
    }

    enum Action: BindableAction, Equatable {
        case binding(BindingAction<State>)
        case setNavigation(Route?)
    }

    var body: some ReducerProtocol<State, Action> {
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
