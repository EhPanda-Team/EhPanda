//
//  TabBarStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/29.
//

import ComposableArchitecture

struct TabBarState: Equatable {
    @BindableState var tabBarItemType: TabBarItemType = .favorites
}

enum TabBarAction: BindableAction {
    case binding(BindingAction<TabBarState>)
}

let tabBarReducer = Reducer<TabBarState, TabBarAction, AnyEnvironment> { _, action, _ in
    Logger.info(action)
    switch action {
    case .binding:
        return .none
    }
}
.binding()
