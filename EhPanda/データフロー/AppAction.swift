//
//  AppAction.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Kanna
import Foundation

enum AppAction {
    case updateUser(user: User?)
    case eraseCachedList
    case initiateFilter
    
    case toggleNavBarHidden(isHidden: Bool)
    
    case toggleSettingPresented
    case toggleWebViewPresented
    case toggleLogoutPresented
    case toggleFilterViewPresented
    case toggleResetFiltersPresented
    case toggleEraseImageCachesPresented
    case toggleEraseCachedListPresented
    case toggleDraftCommentViewPresented_Button
    case toggleDraftCommentViewPresented_BarItem
    
    case cleanCommentContent_Button
    case cleanCommentContent_BarItem
    
    case toggleHomeListType(type: HomeListType)
    
    case fetchSearchItems(keyword: String)
    case fetchSearchItemsDone(result: Result<[Manga], AppError>)
    
    case fetchPopularItems
    case fetchPopularItemsDone(result: Result<[Manga], AppError>)
    
    case fetchFavoritesItems
    case fetchFavoritesItemsDone(result: Result<[Manga], AppError>)
    
    case fetchMangaDetail(id: String)
    case fetchMangaDetailDone(result: Result<(MangaDetail, String), AppError>)
    case fetchAlterImages(id: String, doc: HTMLDocument)
    case fetchAlterImagesDone(result: Result<([Data], String), AppError>)
    
    case updateMangaComments(id: String)
    case updateMangaCommentsDone(result: Result<([MangaComment], String), AppError>)
    
    case fetchMangaContents(id: String)
    case fetchMangaContentsDone(result: Result<([MangaContent], String), AppError>)
    
    case addFavorite(id: String)
    case deleteFavorite(id: String)
    
    case comment(id: String, content: String)
    case editComment(id: String, commentID: String, content: String)
    case voteComment(id: String, commentID: String, vote: Int)
}
