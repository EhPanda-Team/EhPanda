//
//  AppAction.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import UIKit
import Kanna
import Foundation

enum AppAction {
    case replaceUser(user: User)
    case initializeFilter
    case clearDetailViewCommentContent
    case clearCommentViewCommentContent
    case saveAspectBox(gid: String, box: [Int: CGFloat])
    case saveReadingProgress(gid: String, tag: Int)
    case updateDiskImageCacheSize(size: String)
    case updateAppIconType(iconType: IconType)
    case updateHistoryKeywords(text: String)
    case clearHistoryKeywords
    case updateSearchKeyword(text: String)
    case updateViewControllersCount
    case replaceMangaCommentJumpID(gid: String?)
    case updateIsSlideMenuClosed(isClosed: Bool)

    case toggleApp(unlocked: Bool)
    case toggleBlur(effectOn: Bool)
    case toggleHomeList(type: HomeListType)
    case toggleFavorite(index: Int)
    case toggleNavBar(hidden: Bool)
    case toggleHomeViewSheet(state: HomeViewSheetState?)
    case toggleSettingViewSheet(state: SettingViewSheetState?)
    case toggleSettingViewActionSheet(state: SettingViewActionSheetState)
    case toggleFilterViewActionSheet(state: FilterViewActionSheetState)
    case toggleDetailViewSheet(state: DetailViewSheetState?)
    case toggleCommentViewSheet(state: CommentViewSheetState?)

    case fetchGreeting
    case fetchGreetingDone(result: Result<Greeting, AppError>)
    case fetchUserInfo
    case fetchUserInfoDone(result: Result<User, AppError>)
    case fetchFavoriteNames
    case fetchFavoriteNamesDone(result: Result<[Int: String], AppError>)
    case fetchMangaItemReverse(detailURL: String)
    case fetchMangaItemReverseDone(result: Result<Manga, AppError>)
    case fetchSearchItems(keyword: String)
    case fetchSearchItemsDone(result: Result<(Keyword, PageNumber, [Manga]), AppError>)
    case fetchMoreSearchItems(keyword: String)
    case fetchMoreSearchItemsDone(result: Result<(Keyword, PageNumber, [Manga]), AppError>)
    case fetchFrontpageItems
    case fetchFrontpageItemsDone(result: Result<(PageNumber, [Manga]), AppError>)
    case fetchMoreFrontpageItems
    case fetchMoreFrontpageItemsDone(result: Result<(PageNumber, [Manga]), AppError>)
    case fetchPopularItems
    case fetchPopularItemsDone(result: Result<(PageNumber, [Manga]), AppError>)
    case fetchWatchedItems
    case fetchWatchedItemsDone(result: Result<(PageNumber, [Manga]), AppError>)
    case fetchMoreWatchedItems
    case fetchMoreWatchedItemsDone(result: Result<(PageNumber, [Manga]), AppError>)
    case fetchFavoritesItems(index: Int)
    case fetchFavoritesItemsDone(carriedValue: FavoritesIndex, result: Result<(PageNumber, [Manga]), AppError>)
    case fetchMoreFavoritesItems(index: Int)
    case fetchMoreFavoritesItemsDone(carriedValue: FavoritesIndex, result: Result<(PageNumber, [Manga]), AppError>)
    case fetchMangaDetail(gid: String)
    case fetchMangaDetailDone(result: Result<(MangaDetail, MangaState, APIKey?), AppError>)
    case fetchMangaArchiveFunds(gid: String)
    case fetchMangaArchiveFundsDone(result: Result<((CurrentGP, CurrentCredits)), AppError>)
    case fetchAssociatedItems(depth: Int, keyword: AssociatedKeyword)
    case fetchAssociatedItemsDone(result: Result<(Depth, AssociatedKeyword, PageNumber, [Manga]), AppError>)
    case fetchMoreAssociatedItems(depth: Int, keyword: AssociatedKeyword)
    case fetchMoreAssociatedItemsDone(result: Result<(Depth, AssociatedKeyword, PageNumber, [Manga]), AppError>)
    case fetchMangaContents(gid: String)
    case fetchMangaContentsDone(result: Result<(Identity, PageNumber, [MangaContent]), AppError>)
    case fetchMoreMangaContents(gid: String)
    case fetchMoreMangaContentsDone(result: Result<(Identity, PageNumber, [MangaContent]), AppError>)

    case createProfile
    case verifyProfile
    case verifyProfileDone(result: Result<(Int?, Bool), AppError>)
    case addFavorite(gid: String, favIndex: Int)
    case deleteFavorite(gid: String)
    case rate(gid: String, rating: Int)
    case comment(gid: String, content: String)
    case editComment(gid: String, commentID: String, content: String)
    case voteComment(gid: String, commentID: String, vote: Int)
}
