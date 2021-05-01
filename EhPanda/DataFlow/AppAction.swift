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
    case replaceUser(user: User?)
    case clearCachedList
    case clearHistoryItems
    case initiateUser
    case initiateFilter
    case initiateSetting
    case cleanDetailViewCommentContent
    case cleanCommentViewCommentContent
    case saveReadingProgress(gid: String, tag: Int)
    case updateDiskImageCacheSize(size: String)
    case updateAppIconType(iconType: IconType)
    case updateHistoryItems(gid: String)
    case resetDownloadCommandResponse
    case replaceMangaCommentJumpID(gid: String?)
    case updateIsSlideMenuClosed(isClosed: Bool)

    case toggleAppUnlocked(isUnlocked: Bool)
    case toggleBlurEffect(effectOn: Bool)
    case toggleHomeListType(type: HomeListType)
    case toggleFavoriteIndex(index: Int)
    case toggleNavBarHidden(isHidden: Bool)
    case toggleHomeViewSheetState(state: HomeViewSheetState)
    case toggleHomeViewSheetNil
    case toggleSettingViewSheetState(state: SettingViewSheetState)
    case toggleSettingViewSheetNil
    case toggleSettingViewActionSheetState(state: SettingViewActionSheetState)
    case toggleFilterViewActionSheetState(state: FilterViewActionSheetState)
    case toggleDetailViewSheetState(state: DetailViewSheetState)
    case toggleDetailViewSheetNil
    case toggleCommentViewSheetState(state: CommentViewSheetState)
    case toggleCommentViewSheetNil

    case fetchUserInfo(uid: String)
    case fetchUserInfoDone(result: Result<User, AppError>)
    case fetchFavoriteNames
    case fetchFavoriteNamesDone(result: Result<[Int: String], AppError>)
    case fetchMangaItemReverse(detailURL: String)
    case fetchMangaItemReverseDone(result: Result<Manga, AppError>)
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
    case fetchWatchedItems
    case fetchWatchedItemsDone(result: Result<(PageNumber, [Manga]), AppError>)
    case fetchMoreWatchedItems
    case fetchMoreWatchedItemsDone(result: Result<(PageNumber, [Manga]), AppError>)
    case fetchFavoritesItems(index: Int)
    case fetchFavoritesItemsDone(carriedValue: FavoritesIndex, result: Result<(PageNumber, [Manga]), AppError>)
    case fetchMoreFavoritesItems(index: Int)
    case fetchMoreFavoritesItemsDone(carriedValue: FavoritesIndex, result: Result<(PageNumber, [Manga]), AppError>)
    case fetchMangaDetail(gid: String)
    case fetchMangaDetailDone(result: Result<(Identity, MangaDetail, APIKey), AppError>)
    case fetchMangaArchive(gid: String)
    case fetchMangaArchiveDone(result: Result<(Identity, MangaArchive, CurrentGP?, CurrentCredits?), AppError>)
    case fetchMangaArchiveFunds(gid: String)
    case fetchMangaArchiveFundsDone(result: Result<((CurrentGP, CurrentCredits)), AppError>)
    case fetchMangaTorrents(gid: String)
    case fetchMangaTorrentsDone(result: Result<(Identity, [MangaTorrent]), AppError>)
    case fetchAssociatedItems(depth: Int, keyword: AssociatedKeyword)
    case fetchAssociatedItemsDone(result: Result<(Depth, AssociatedKeyword, PageNumber, [Manga]), AppError>)
    case fetchMoreAssociatedItems(depth: Int, keyword: AssociatedKeyword)
    case fetchMoreAssociatedItemsDone(result: Result<(Depth, AssociatedKeyword, PageNumber, [Manga]), AppError>)
    case fetchAlterImages(gid: String, doc: HTMLDocument)
    case fetchAlterImagesDone(result: Result<(Identity, [MangaAlterData]), AppError>)
    case updateMangaComments(gid: String)
    case updateMangaCommentsDone(result: Result<(Identity, [MangaComment]), AppError>)
    case updateMangaDetail(gid: String)
    case updateMangaDetailDone(result: Result<(Identity, MangaDetail), AppError>)
    case fetchMangaContents(gid: String)
    case fetchMangaContentsDone(result: Result<(Identity, PageNumber, [MangaContent]), AppError>)
    case fetchMoreMangaContents(gid: String)
    case fetchMoreMangaContentsDone(result: Result<(Identity, PageNumber, [MangaContent]), AppError>)

    case addFavorite(gid: String, favIndex: Int)
    case deleteFavorite(gid: String)
    case sendDownloadCommand(gid: String, resolution: String)
    case sendDownloadCommandDone(result: Result<Resp?, AppError>)
    case rate(gid: String, rating: Int)
    case comment(gid: String, content: String)
    case editComment(gid: String, commentID: String, content: String)
    case voteComment(gid: String, commentID: String, vote: Int)
}
