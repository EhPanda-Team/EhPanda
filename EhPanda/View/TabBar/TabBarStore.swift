//
//  TabBarStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/29.
//

import ComposableArchitecture

struct TabBarState: Equatable {
    @BindableState var tabBarItemType: TabBarItemType = .home
}
