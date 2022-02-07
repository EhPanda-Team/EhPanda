//
//  TabBarStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/29.
//

import ComposableArchitecture

struct TabBarState: Equatable {
    var tabBarItemType: TabBarItemType = .home
}

enum TabBarAction {
    case setTabBarItemType(TabBarItemType)
}

struct TabBarEnvironment {
    let deviceClient: DeviceClient
}

let tabBarReducer = Reducer<TabBarState, TabBarAction, TabBarEnvironment> { state, action, environment in
    switch action {
    case .setTabBarItemType(let type):
        if !environment.deviceClient.isPad() || type != .setting {
            state.tabBarItemType = type
        }
        return .none
    }
}
