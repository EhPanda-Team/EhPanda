//
//  AppAction.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import UIKit
import Kanna
import Foundation

enum DeprecatedAppAction {
    // swiftlint:disable line_length
    case setReadingProgress(gid: String, tag: Int)
    case appendHistoryKeywords(texts: [String])
    case removeHistoryKeyword(text: String)
    case clearHistoryKeywords
    case setGalleryCommentJumpID(gid: String?)
    case fulfillGalleryPreviews(gid: String)
    case fulfillGalleryContents(gid: String)
    case setPendingJumpInfos(gid: String, pageIndex: Int?, commentID: String?)
    case appendQuickSearchWord
    case deleteQuickSearchWord(offsets: IndexSet)
    case modifyQuickSearchWord(newWord: QuickSearchWord)
    case moveQuickSearchWord(source: IndexSet, destination: Int)

    case fetchGreeting
    case fetchGreetingDone(result: Result<Greeting, AppError>)
    case fetchGalleryItemReverse(url: String, shouldParseGalleryURL: Bool)
    case fetchGalleryItemReverseDone(carriedValue: String, result: Result<Gallery, AppError>)
    case fetchSearchItems(keyword: String, pageNum: Int? = nil)
    case fetchSearchItemsDone(result: Result<(PageNumber, [Gallery]), AppError>)
    case fetchMoreSearchItems(keyword: String)
    case fetchMoreSearchItemsDone(result: Result<(PageNumber, [Gallery]), AppError>)
    case fetchWatchedItems(pageNum: Int? = nil)
    case fetchWatchedItemsDone(result: Result<(PageNumber, [Gallery]), AppError>)
    case fetchMoreWatchedItems
    case fetchMoreWatchedItemsDone(result: Result<(PageNumber, [Gallery]), AppError>)
    case fetchGalleryDetail(gid: String)
    case fetchGalleryDetailDone(gid: String, result: Result<(GalleryDetail, GalleryState, APIKey, Greeting?), AppError>)
    case fetchGalleryArchiveFunds(gid: String)
    case fetchGalleryArchiveFundsDone(result: Result<((CurrentGP, CurrentCredits)), AppError>)
    case fetchGalleryPreviews(gid: String, index: Int)
    case fetchGalleryPreviewsDone(gid: String, pageNumber: Int, result: Result<[Int: String], AppError>)
    case fetchMPVKeys(gid: String, index: Int, mpvURL: String)
    case fetchMPVKeysDone(gid: String, index: Int, result: Result<(String, [Int: String]), AppError>)
    case fetchThumbnails(gid: String, index: Int)
    case fetchThumbnailsDone(gid: String, index: Int, result: Result<[Int: String], AppError>)
    case fetchGalleryNormalContents(gid: String, index: Int, thumbnails: [Int: String])
    case fetchGalleryNormalContentsDone(gid: String, index: Int, result: Result<([Int: String], [Int: String]), AppError>)
    case refetchGalleryNormalContent(gid: String, index: Int)
    case refetchGalleryNormalContentDone(gid: String, index: Int, result: Result<[Int: String], AppError>)
    case fetchGalleryMPVContent(gid: String, index: Int, isRefetch: Bool = false)
    case fetchGalleryMPVContentDone(gid: String, index: Int, result: Result<(String, String?, ReloadToken), AppError>)

    case favorGallery(gid: String, favIndex: Int)
    case unfavorGallery(gid: String)
    case rateGallery(gid: String, rating: Int)
    case commentGallery(gid: String, content: String)
    case editGalleryComment(gid: String, commentID: String, content: String)
    case voteGalleryComment(gid: String, commentID: String, vote: Int)
    // swiftlint:enable line_length
}
