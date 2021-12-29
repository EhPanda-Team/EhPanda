//
//  AltAppAction.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import Foundation

enum AltAppAction {
    case appDelegate(AppDelegateAction)
    case userData(UserDataAction)
    case favorites(FavoritesAction)
}
