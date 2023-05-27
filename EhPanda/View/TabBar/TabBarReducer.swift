//
//  TabBarReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/29.
//

import ComposableArchitecture

struct TabBarReducer: ReducerProtocol {
    struct State: Equatable {
        var tabBarItemType: TabBarItemType = .home
    }

    enum Action: Equatable {
        case setTabBarItemType(TabBarItemType)
    }

    @Dependency(\.deviceClient) private var deviceClient

    var body: some ReducerProtocol<State, Action> {
        Reduce { state, action in
            switch action {
            case .setTabBarItemType(let type):
                if !deviceClient.isPad() || type != .setting {
                    state.tabBarItemType = type
                }
                return .none
            }
        }
    }
}
