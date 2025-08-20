//
//  TabBarReducer.swift
//  EhPanda
//

import ComposableArchitecture

@Reducer
struct TabBarReducer {
    @ObservableState
    struct State: Equatable {
        var tabBarItemType: TabBarItemType = .home
    }

    enum Action: Equatable {
        case setTabBarItemType(TabBarItemType)
    }

    @Dependency(\.deviceClient) private var deviceClient

    var body: some Reducer<State, Action> {
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
