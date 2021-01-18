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
    case clearCachedList
    case initiateFilter
    case initiateSetting
    case cleanDetailViewCommentContent
    case cleanCommentViewCommentContent
    case saveReadingProgress(id: String, tag: Int)
    case updateDiskImageCacheSize(size: String)
    
    case toggleNavBarHidden(isHidden: Bool)
    case toggleHomeListType(type: HomeListType)
    case toggleHomeViewSheetState(state: HomeViewSheetState)
    case toggleSettingViewSheetState(state: SettingViewSheetState)
    case toggleSettingViewSheetNil
    case toggleSettingViewActionSheetState(state: SettingViewActionSheetState)
    case toggleFilterViewActionSheetState(state: FilterViewActionSheetState)
    case toggleDetailViewSheetState(state: DetailViewSheetState)
    case toggleDetailViewSheetNil
    case toggleCommentViewSheetState(state: CommentViewSheetState)
    case toggleCommentViewSheetNil
    
    case fetchSearchItems(keyword: String)
    case fetchSearchItemsDone(result: Result<(PageNumber, [Manga]), AppError>)
    case fetchMoreSearchItems(keyword: String)
    case fetchMoreSearchItemsDone(result: Result<(Keyword, PageNumber, [Manga]), AppError>)
    case fetchFrontpageItems
    case fetchFrontpageItemsDone(result: Result<(PageNumber, [Manga]), AppError>)
    case fetchMoreFrontpageItems
    case fetchMoreFrontpageItemsDone(result: Result<(PageNumber, [Manga]), AppError>)
    case fetchPopularItems
    case fetchPopularItemsDone(result: Result<(PageNumber, [Manga]), AppError>)
    case fetchFavoritesItems
    case fetchFavoritesItemsDone(result: Result<(PageNumber, [Manga]), AppError>)
    case fetchMoreFavoritesItems
    case fetchMoreFavoritesItemsDone(result: Result<(PageNumber, [Manga]), AppError>)
    case fetchMangaDetail(id: String)
    case fetchMangaDetailDone(result: Result<(Identity, MangaDetail), AppError>)
    case fetchAssociatedItems(depth: Int, keyword: AssociatedKeyword)
    case fetchAssociatedItemsDone(result: Result<(Depth, AssociatedKeyword, PageNumber, [Manga]), AppError>)
    case fetchMoreAssociatedItems(depth: Int, keyword: AssociatedKeyword)
    case fetchMoreAssociatedItemsDone(result: Result<(Depth, AssociatedKeyword, PageNumber, [Manga]), AppError>)
    case fetchAlterImages(id: String, doc: HTMLDocument)
    case fetchAlterImagesDone(result: Result<(Identity, [Data]), AppError>)
    case updateMangaComments(id: String)
    case updateMangaCommentsDone(result: Result<(Identity, [MangaComment]), AppError>)
    case fetchMangaContents(id: String)
    case fetchMangaContentsDone(result: Result<(Identity, [MangaContent]), AppError>)
    
    case addFavorite(id: String)
    case deleteFavorite(id: String)
    case comment(id: String, content: String)
    case editComment(id: String, commentID: String, content: String)
    case voteComment(id: String, commentID: String, vote: Int)
}
