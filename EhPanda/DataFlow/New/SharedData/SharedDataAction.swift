//
//  SharedDataAction.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/25.
//

import Foundation
import ComposableArchitecture

enum SharedDataAction: BindableAction {
    case didFinishLaunching
    case didFinishLogining
    case createDefaultEhProfile
    case fetchIgneous
    case fetchUserInfo
    case fetchUserInfoDone(Result<User, AppError>)
    case fetchTagTranslator(String)
    case fetchTagTranslatorDone(Result<TagTranslator, AppError>)
    case fetchEhProfileIndex
    case fetchEhProfileIndexDone(Result<(Int?, Bool), AppError>)
    case fetchFavoriteNames
    case fetchFavoriteNamesDone(Result<[Int: String], AppError>)

    case binding(BindingAction<SharedData>)
    case logout
}
