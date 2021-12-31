//
//  AltAppState.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import SwiftUI
import ComposableArchitecture

struct AltAppState: Equatable {
    var sharedData = SharedData()

    var tabBarState = TabBarState()
    var favoritesState = FavoritesState()
    var settingState = SettingState()
}
