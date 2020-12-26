//
//  AppAction.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

enum AppAction {
    case toggleNavBarHidden(isHidden: Bool)
    
    case toggleSettingPresented
    case toggleHomeListType(type: HomeListType)
    
    case fetchSearchItems(keyword: String)
    case fetchSearchItemsDone(result: Result<[Manga], AppError>)
    
    case fetchPopularItems
    case fetchPopularItemsDone(result: Result<[Manga], AppError>)
}
