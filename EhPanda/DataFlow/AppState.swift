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
}

extension AppState {
    // MARK: Environment
    struct Environment {
        var isPreview = false
        var isAppUnlocked = true
        var blurRadius: CGFloat = 0
        var viewControllersCount = 1
        var isSlideMenuClosed = true
        var navBarHidden = false
        var favoritesIndex = -1
        var homeListType: HomeListType = .frontpage
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
        var greetingLoading = false

        @FileStorage(directory: .cachesDirectory, fileName: "user.json")
        var user: User?
        @FileStorage(directory: .cachesDirectory, fileName: "filter.json")
        var filter: Filter?
        @FileStorage(directory: .cachesDirectory, fileName: "setting.json")
        var setting: Setting?

        mutating func update(user: User) {
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

        mutating func insert(greeting: Greeting) {
            guard let currDate = greeting.updateTime
            else { return }

            if let prevGreeting = user?.greeting,
               let prevDate = prevGreeting.updateTime,
               prevDate < currDate
            {
                user?.greeting = greeting
            } else if user?.greeting == nil {
                user?.greeting = greeting
            }
        }
    }
}

extension AppState {
    // MARK: HomeInfo
    struct HomeInfo {
        var searchKeyword = ""

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
        var favoritesPageNumMaximum = generateIntDic(defaultValue: 1)
        var moreFavoritesLoading = generateBoolDic()
        var moreFavoritesLoadFailed = generateBoolDic()

        @FileStorage(directory: .cachesDirectory, fileName: "historyList.json")
        var historyItems: [String: Manga]?
        @FileStorage(directory: .cachesDirectory, fileName: "historyKeywords.json")
        var historyKeywords: [String]?

        static func generateBoolDic(defaultValue: Bool = false) -> [Int: Bool] {
            var tmp = [Int: Bool]()
            (-1..<10).forEach { index in
                tmp[index] = defaultValue
            }
            return tmp
        }

        static func generateIntDic(defaultValue: Int = 0) -> [Int: Int] {
            var tmp = [Int: Int]()
            (-1..<10).forEach { index in
                tmp[index] = defaultValue
            }
            return tmp
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
        mutating func insertHistoryKeyword(text: String) {
            guard !text.isEmpty else { return }
            guard var historyKeywords = historyKeywords else {
                historyKeywords = [text]
                return
            }

            if let index = historyKeywords.firstIndex(of: text) {
                if historyKeywords.last != text {
                    historyKeywords.remove(at: index)
                    historyKeywords.append(text)
                }
            } else {
                historyKeywords.append(text)

                let overflow = historyKeywords.count - 10

                if overflow > 0 {
                    historyKeywords = Array(
                        historyKeywords.dropFirst(overflow)
                    )
                }
            }

            self.historyKeywords = historyKeywords
        }
    }

    // MARK: DetailInfo
    struct DetailInfo {
        var commentContent = ""

        var mangaDetailLoading = false
        var mangaDetailLoadFailed = false

        var mangaArchiveFundsLoading = false

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
            if associatedItems.count > depth {
                associatedItems[depth].keyword = keyword
                associatedItems[depth].pageNum = pageNum
                associatedItems[depth].mangas.append(contentsOf: items)
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
