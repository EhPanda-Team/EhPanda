//
//  AppState.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import SwiftUI
import Foundation

struct AppState {
    var environment = Environment()
    var settings = Settings()
    var homeInfo = HomeInfo()
    var detailInfo = DetailInfo()
    var commentInfo = CommentInfo()
    var contentInfo = ContentInfo()
    var cachedList = CachedList()
}

extension AppState {
    // MARK: Environment
    struct Environment {
        var isPreview = false
        var isAppUnlocked = true
        var blurRadius: CGFloat = 0
        var isSlideMenuClosed = true
        var navBarHidden = false
        var homeListType: HomeListType = .frontpage
        var favoritesIndex = -1
        var homeViewSheetState: HomeViewSheetState?
        var settingViewSheetState: SettingViewSheetState?
        var settingViewActionSheetState: SettingViewActionSheetState?
        var filterViewActionSheetState: FilterViewActionSheetState?
        var detailViewSheetState: DetailViewSheetState?
        var commentViewSheetState: CommentViewSheetState?

        var mangaItemReverseID: String?
        var mangaItemReverseLoading = false
        var mangaItemReverseLoadFailed = false
    }

    // MARK: Settings
    struct Settings {
        var userInfoLoading = false
        var favoriteNamesLoading = false

        @FileStorage(directory: .cachesDirectory, fileName: "user.json")
        var user: User?
        @FileStorage(directory: .cachesDirectory, fileName: "filter.json")
        var filter: Filter?
        @FileStorage(directory: .cachesDirectory, fileName: "setting.json")
        var setting: Setting?

        mutating func updateUser(_ user: User) {
            if let displayName = user.displayName {
                self.user?.displayName = displayName
            }
            if let avatarURL = user.avatarURL {
                self.user?.avatarURL = avatarURL
            }
            if let currentGP = user.currentGP,
               let currentCredits = user.currentCredits
            {
                self.user?.currentGP = currentGP
                self.user?.currentCredits = currentCredits
            }
        }
    }
}

extension AppState {
    // MARK: HomeInfo
    struct HomeInfo {
        var searchKeyword = ""
        var greeting: Greeting?
        var greetingLoading = false

        var searchItems: [Manga]?
        var searchLoading = false
        var searchNotFound = false
        var searchLoadFailed = false
        var searchCurrentPageNum = 0
        var searchPageNumMaximum = 1
        var moreSearchLoading = false
        var moreSearchLoadFailed = false

        var frontpageItems: [Manga]?
        var frontpageLoading = false
        var frontpageNotFound = false
        var frontpageLoadFailed = false
        var frontpageCurrentPageNum = 0
        var frontpagePageNumMaximum = 1
        var moreFrontpageLoading = false
        var moreFrontpageLoadFailed = false

        var popularItems: [Manga]?
        var popularLoading = false
        var popularNotFound = false
        var popularLoadFailed = false

        var watchedItems: [Manga]?
        var watchedLoading = false
        var watchedNotFound = false
        var watchedLoadFailed = false
        var watchedCurrentPageNum = 0
        var watchedPageNumMaximum = 1
        var moreWatchedLoading = false
        var moreWatchedLoadFailed = false

        var favoritesItems = [Int: [Manga]]()
        var favoritesLoading = generateBoolDic()
        var favoritesNotFound = generateBoolDic()
        var favoritesLoadFailed = generateBoolDic()
        var favoritesCurrentPageNum = generateIntDic()
        var favoritesPageNumMaximum = generateIntDic(1)
        var moreFavoritesLoading = generateBoolDic()
        var moreFavoritesLoadFailed = generateBoolDic()

        @FileStorage(directory: .cachesDirectory, fileName: "historyList.json")
        var historyItems: [String: Manga]?

        static func generateBoolDic(_ defaultValue: Bool = false) -> [Int: Bool] {
            var tmp = [Int: Bool]()
            (-1..<10).forEach { index in
                tmp[index] = defaultValue
            }
            return tmp
        }

        static func generateIntDic(_ defaultValue: Int = 0) -> [Int: Int] {
            var tmp = [Int: Int]()
            (-1..<10).forEach { index in
                tmp[index] = defaultValue
            }
            return tmp
        }

        mutating func insertGreeting(greeting: Greeting) {
            guard let currDate = self.greeting?.updateTime
            else { return }

            if let prevGreeting = self.greeting,
               let prevDate = prevGreeting.updateTime,
               prevDate < currDate
            {
                self.greeting = greeting
            } else if self.greeting == nil {
                self.greeting = greeting
            }
        }

        mutating func insertSearchItems(mangas: [Manga]) {
            mangas.forEach { manga in
                if searchItems?.contains(manga) == false {
                    searchItems?.append(manga)
                }
            }
        }
        mutating func insertFrontpageItems(mangas: [Manga]) {
            mangas.forEach { manga in
                if frontpageItems?.contains(manga) == false {
                    frontpageItems?.append(manga)
                }
            }
        }
        mutating func insertWatchedItems(mangas: [Manga]) {
            mangas.forEach { manga in
                if watchedItems?.contains(manga) == false {
                    watchedItems?.append(manga)
                }
            }
        }
        mutating func insertFavoritesItems(favIndex: Int, mangas: [Manga]) {
            mangas.forEach { manga in
                if favoritesItems[favIndex]?.contains(manga) == false {
                    favoritesItems[favIndex]?.append(manga)
                }
            }
        }
        mutating func insertHistoryItem(manga: Manga?) {
            guard var manga = manga else { return }
            if historyItems != nil {
                if historyItems?.keys.contains(manga.gid) == true {
                    historyItems?[manga.gid]?.lastOpenTime = Date()
                } else {
                    manga.lastOpenTime = Date()
                    historyItems?[manga.gid] = manga
                }
            } else {
                historyItems = Dictionary(
                    uniqueKeysWithValues: [(manga.gid, manga)]
                )
            }
        }
    }

    // MARK: DetailInfo
    struct DetailInfo {
        var commentContent = ""

        var mangaDetailLoading = false
        var mangaDetailLoadFailed = false

        var mangaArchiveLoading = false
        var mangaArchiveLoadFailed = false
        var mangaArchiveFundsLoading = false

        var downloadCommandResponse: String?
        var downloadCommandSending = false
        var downloadCommandFailed = false

        var mangaTorrentsLoading = false
        var mangaTorrentsLoadFailed = false

        var associatedItems: [AssociatedItem] = []
        var associatedItemsLoading = false
        var associatedItemsNotFound = false
        var associatedItemsLoadFailed = false
        var moreAssociatedItemsLoading = false
        var moreAssociatedItemsLoadFailed = false

        var alterImagesLoading = false

        var mangaDetailUpdating = false
        var mangaCommentsUpdating = false

        mutating func removeAssociatedItems(depth: Int) {
            if associatedItems.count >= depth + 1 {
                associatedItems[depth].mangas = []
            }
        }

        mutating func replaceAssociatedItems(
            depth: Int,
            keyword: AssociatedKeyword,
            pageNum: PageNumber,
            items: [Manga]
        ) {
            if associatedItems.count >= depth + 1 {
                associatedItems[depth] = AssociatedItem(
                    keyword: keyword,
                    pageNum: pageNum,
                    mangas: items
                )
            } else {
                associatedItems
                    .append(AssociatedItem(
                        keyword: keyword,
                        pageNum: pageNum,
                        mangas: items
                ))
            }
        }

        mutating func insertAssociatedItems(
            depth: Int,
            keyword: AssociatedKeyword,
            pageNum: PageNumber,
            items: [Manga]
        ) {
            if associatedItems.count >= depth + 1 {
                associatedItems[depth].keyword = keyword
                associatedItems[depth].pageNum = pageNum
                associatedItems[depth].mangas.append(contentsOf: items)
            } else {
                print("AssociatedItemsUpdating: Not found")
            }
        }
    }

    struct CommentInfo {
        var commentContent = ""
    }

    struct ContentInfo {
        var mangaContentsLoading = false
        var mangaContentsLoadFailed = false
        var moreMangaContentsLoading = false
        var moreMangaContentsLoadFailed = false
    }
}

extension AppState {
    // MARK: CachedList
    struct CachedList {
        @FileStorage(directory: .cachesDirectory, fileName: "cachedList.json")
        var items: [String: Manga]?

        func hasCached(gid: String) -> Bool {
            items?[gid] != nil
        }
        mutating func cache(mangas: [Manga]) {
            let previousCount = items?.count ?? 0
            if items == nil {
                items = Dictionary(uniqueKeysWithValues: mangas.map { ($0.id, $0) })
                return
            }

            for manga in mangas {
                if items?[manga.gid] == nil {
                    items?[manga.gid] = manga
                } else {
                    items?[manga.gid]?.title = manga.title
                    items?[manga.gid]?.rating = manga.rating
                    items?[manga.gid]?.tags = manga.tags
                    items?[manga.gid]?.language = manga.language
                }
            }
            let currentCount = items?.count ?? 0
            print("キャッシュ済みリスト 更新: \(previousCount) -> \(currentCount)")
        }

        mutating func insertDetail(gid: String, detail: MangaDetail) {
            items?[gid]?.detail = detail
        }
        mutating func insertArchive(gid: String, archive: MangaArchive) {
            items?[gid]?.detail?.archive = archive
        }
        mutating func insertTorrents(gid: String, torrents: [MangaTorrent]) {
            items?[gid]?.detail?.torrents = torrents
        }
        mutating func updateDetail(gid: String, detail: MangaDetail) {
            items?[gid]?.detail?.isFavored = detail.isFavored
            items?[gid]?.detail?.archiveURL = detail.archiveURL
            items?[gid]?.detail?.detailTags = detail.detailTags
            items?[gid]?.detail?.comments = detail.comments
            items?[gid]?.detail?.jpnTitle = detail.jpnTitle
            items?[gid]?.detail?.likeCount = detail.likeCount
            items?[gid]?.detail?.pageCount = detail.pageCount
            items?[gid]?.detail?.sizeCount = detail.sizeCount
            items?[gid]?.detail?.sizeType = detail.sizeType
            items?[gid]?.detail?.rating = detail.rating
            items?[gid]?.detail?.userRating = detail.userRating
            items?[gid]?.detail?.ratingCount = detail.ratingCount
            items?[gid]?.detail?.torrentCount = detail.torrentCount
        }
        mutating func insertAlterImages(gid: String, images: [MangaAlterData]) {
            items?[gid]?.detail?.alterImages = images
        }
        mutating func updateComments(gid: String, comments: [MangaComment]) {
            items?[gid]?.detail?.comments = comments
        }
        mutating func insertContents(gid: String, pageNum: PageNumber, contents: [MangaContent]) {
            items?[gid]?.detail?.currentPageNum = pageNum.current
            items?[gid]?.detail?.pageNumMaximum = pageNum.maximum

            if items?[gid]?.contents == nil {
                items?[gid]?.contents = contents.sorted { $0.tag < $1.tag }
            } else {
                contents.forEach { content in
                    if items?[gid]?.contents?.contains(content) == false {
                        items?[gid]?.contents?.append(content)
                    }
                }
                items?[gid]?.contents?.sort { $0.tag < $1.tag }
            }
        }
        mutating func insertReadingProgress(gid: String, progress: Int) {
            items?[gid]?.detail?.readingProgress = progress
        }
    }
}
