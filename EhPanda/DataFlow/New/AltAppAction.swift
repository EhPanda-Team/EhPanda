//
//  AltAppAction.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import Foundation

enum AltAppAction {
    case appDelegate(AppDelegateAction)
    case sharedData(SharedDataAction)

    case tabBar(TabBarAction)
    case favorites(FavoritesAction)
    case setting(SettingAction)
}
