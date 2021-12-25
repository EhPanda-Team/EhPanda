//
//  UserDataAction.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import Foundation

enum UserDataAction {
    case didFinishLaunching
    case createDefaultEhProfile
    case fetchIgneous
    case fetchUserInfo
    case fetchUserInfoDone(Result<User, AppError>)
    case fetchEhProfileIndex
    case fetchEhProfileIndexDone(Result<(Int?, Bool), AppError>)
    case fetchFavoriteNames
    case fetchFavoriteNamesDone(Result<[Int: String], AppError>)
}
