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
    case resetUser
    case resetFilters
    case saveReadingProgress(gid: String, tag: Int)
    case updateDiskImageCacheSize(size: String)
    case updateAppIconType(iconType: IconType)
    case updateHistoryKeywords(text: String)
    case clearHistoryKeywords
    case updateSearchKeyword(text: String)
    case updateViewControllersCount
    case updateSetting(setting: Setting)
    case replaceGalleryCommentJumpID(gid: String?)
    case updateIsSlideMenuClosed(isClosed: Bool)
    case fulfillGalleryPreviews(gid: String)
    case fulfillGalleryContents(gid: String)
    case updatePendingJumpInfos(gid: String, pageIndex: Int?, commentID: String?)

    case toggleApp(unlocked: Bool)
    case toggleBlur(effectOn: Bool)
    case toggleHomeList(type: HomeListType)
    case toggleFavorites(index: Int)
    case toggleToplists(type: ToplistsType)
    case toggleNavBar(hidden: Bool)
    case toggleHomeViewSheet(state: HomeViewSheetState?)
    case toggleSettingViewSheet(state: SettingViewSheetState?)
    case toggleSettingViewActionSheet(state: SettingViewActionSheetState)
    case toggleFilterViewActionSheet(state: FilterViewActionSheetState)
    case toggleDetailViewSheet(state: DetailViewSheetState?)
    case toggleCommentViewSheet(state: CommentViewSheetState?)

    case fetchIgneous
    case fetchTagTranslator
    case fetchTagTranslatorDone(result: Result<TagTranslator, AppError>)
    case fetchGreeting
    case fetchGreetingDone(result: Result<Greeting, AppError>)
    case fetchUserInfo
    case fetchUserInfoDone(result: Result<User, AppError>)
    case fetchFavoriteNames
    case fetchFavoriteNamesDone(result: Result<[Int: String], AppError>)
    case fetchGalleryItemReverse(url: String, shouldParseGalleryURL: Bool)
    case fetchGalleryItemReverseDone(carriedValue: String, result: Result<Gallery, AppError>)
    case fetchSearchItems(keyword: String)
    case fetchSearchItemsDone(result: Result<(PageNumber, [Gallery]), AppError>)
    case fetchMoreSearchItems(keyword: String)
    case fetchMoreSearchItemsDone(result: Result<(PageNumber, [Gallery]), AppError>)
    case fetchFrontpageItems
    case fetchFrontpageItemsDone(result: Result<(PageNumber, [Gallery]), AppError>)
    case fetchMoreFrontpageItems
    case fetchMoreFrontpageItemsDone(result: Result<(PageNumber, [Gallery]), AppError>)
    case fetchPopularItems
    case fetchPopularItemsDone(result: Result<[Gallery], AppError>)
    case fetchWatchedItems
    case fetchWatchedItemsDone(result: Result<(PageNumber, [Gallery]), AppError>)
    case fetchMoreWatchedItems
    case fetchMoreWatchedItemsDone(result: Result<(PageNumber, [Gallery]), AppError>)
    case fetchFavoritesItems
    case fetchFavoritesItemsDone(carriedValue: Int, result: Result<(PageNumber, [Gallery]), AppError>)
    case fetchMoreFavoritesItems
    case fetchMoreFavoritesItemsDone(carriedValue: Int, result: Result<(PageNumber, [Gallery]), AppError>)
    case fetchToplistsItems
    case fetchToplistsItemsDone(carriedValue: Int, result: Result<(PageNumber, [Gallery]), AppError>)
    case fetchMoreToplistsItems
    case fetchMoreToplistsItemsDone(carriedValue: Int, result: Result<(PageNumber, [Gallery]), AppError>)
    case fetchGalleryDetail(gid: String)
    case fetchGalleryDetailDone(gid: String, result: Result<(GalleryDetail, GalleryState, APIKey?), AppError>)
    case fetchGalleryArchiveFunds(gid: String)
    case fetchGalleryArchiveFundsDone(result: Result<((CurrentGP, CurrentCredits)), AppError>)
    case fetchGalleryPreviews(gid: String, index: Int)
    case fetchGalleryPreviewsDone(gid: String, pageNumber: Int, result: Result<[Int: String], AppError>)
    case fetchMPVKeys(gid: String, index: Int, mpvURL: String)
    case fetchMPVKeysDone(gid: String, index: Int, result: Result<(String, [Int: String]), AppError>)
    case fetchThumbnailURLs(gid: String, index: Int)
    case fetchThumbnailURLsDone(gid: String, index: Int, result: Result<[(Int, URL)], AppError>)
    case fetchGalleryNormalContents(gid: String, index: Int, thumbnailURLs: [(Int, URL)])
    case fetchGalleryNormalContentsDone(gid: String, index: Int, result: Result<[Int: String], AppError>)
    case fetchGalleryMPVContent(gid: String, index: Int)
    case fetchGalleryMPVContentDone(gid: String, index: Int, result: Result<String, AppError>)

    case createEhProfile(name: String)
    case verifyEhProfile
    case verifyEhProfileDone(result: Result<(Int?, Bool), AppError>)
    case addFavorite(gid: String, favIndex: Int)
    case deleteFavorite(gid: String)
    case rate(gid: String, rating: Int)
    case comment(gid: String, content: String)
    case editComment(gid: String, commentID: String, content: String)
    case voteComment(gid: String, commentID: String, vote: Int)
}
