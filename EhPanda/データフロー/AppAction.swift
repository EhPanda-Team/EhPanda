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
    case initiateSetting
    case cleanDetailViewCommentContent
    case cleanCommentViewCommentContent
    case saveReadingProgress(id: String, tag: Int)
    
    case toggleNavBarHidden(isHidden: Bool)
    case toggleHomeListType(type: HomeListType)
    case toggleHomeViewSheetState(state: HomeViewSheetState)
    case toggleSettingViewActionSheetState(state: SettingViewActionSheetState)
    case toggleFilterViewActionSheetState(state: FilterViewActionSheetState)
    case toggleDetailViewSheetState(state: DetailViewSheetState)
    case toggleDetailViewSheetNil
    case toggleCommentViewSheetState(state: CommentViewSheetState)
    case toggleCommentViewSheetNil
    
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
