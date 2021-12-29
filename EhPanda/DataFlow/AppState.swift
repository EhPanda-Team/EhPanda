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
    var contentInfo = ContentInfo()
}

extension AppState {
    // MARK: Environment
    struct Environment {
        var isPreview = false
        var isAppUnlocked = true
        var blurRadius: CGFloat = 0
        var viewControllersCount = 1
        var navigationBarHidden = false
        var favoritesIndex = -1
        var favoritesSortOrder: FavoritesSortOrder?
        var toplistsType: ToplistsType = .allTime
        // var homeListType: HomeListType = .frontpage
        var homeViewSheetState: HomeViewSheetState?
        var settingViewSheetState: SettingViewSheetState?
        var detailViewSheetState: DetailViewSheetState?
        var commentViewSheetState: CommentViewSheetState?

        var galleryItemReverseID: String?
        var galleryItemReverseLoading = false
        var galleryItemReverseLoadFailed = false
    }

    // MARK: Settings
    struct Settings {
        var userInfoLoading = false
        var favoriteNamesLoading = false
        var greetingLoading = false

        var appEnv: AppEnv {
            PersistenceController.fetchAppEnvNonNil()
        }

        @AppEnvStorage(type: User.self)
        var user: User

        @AppEnvStorage(type: Filter.self, key: "searchFilter")
        var searchFilter: Filter

        @AppEnvStorage(type: Filter.self, key: "globalFilter")
        var globalFilter: Filter

        @AppEnvStorage(type: Setting.self)
        var setting: Setting

        @AppEnvStorage(type: TagTranslator.self, key: "tagTranslator")
        var tagTranslator: TagTranslator

        mutating func update(user: User) {
            if let displayName = user.displayName {
                self.user.displayName = displayName
            }
            if let avatarURL = user.avatarURL {
                self.user.avatarURL = avatarURL
            }
            if let currentGP = user.currentGP,
               let currentCredits = user.currentCredits
            {
                self.user.currentGP = currentGP
                self.user.currentCredits = currentCredits
            }
        }

        mutating func insert(greeting: Greeting) {
            guard let currDate = greeting.updateTime
            else { return }

            if let prevGreeting = user.greeting,
               let prevDate = prevGreeting.updateTime,
               prevDate < currDate
            {
                user.greeting = greeting
            } else if user.greeting == nil {
                user.greeting = greeting
            }
        }
    }
}

extension AppState {
    // MARK: HomeInfo
    struct HomeInfo {
        var searchItems = [Gallery]()
        var searchLoading = false
        var searchLoadError: AppError?
        var searchPageNumber = PageNumber()
        var moreSearchLoading = false
        var moreSearchLoadFailed = false

        var frontpageItems = [Gallery]()
        var frontpageLoading = false
        var frontpageLoadError: AppError?
        var frontpagePageNumber = PageNumber()
        var moreFrontpageLoading = false
        var moreFrontpageLoadFailed = false

        var popularItems = [Gallery]()
        var popularLoading = false
        var popularLoadError: AppError?

        var watchedItems = [Gallery]()
        var watchedLoading = false
        var watchedLoadError: AppError?
        var watchedPageNumber = PageNumber()
        var moreWatchedLoading = false
        var moreWatchedLoadFailed = false

        var favoritesItems = [Int: [Gallery]]()
        var favoritesLoading = [Int: Bool]()
        var favoritesLoadErrors = [Int: AppError]()
        var favoritesPageNumbers = [Int: PageNumber]()
        var moreFavoritesLoading = [Int: Bool]()
        var moreFavoritesLoadFailed = [Int: Bool]()

        var toplistsItems = [Int: [Gallery]]()
        var toplistsLoading = [Int: Bool]()
        var toplistsLoadErrors = [Int: AppError]()
        var toplistsPageNumbers = [Int: PageNumber]()
        var moreToplistsLoading = [Int: Bool]()
        var moreToplistsLoadFailed = [Int: Bool]()

        @AppEnvStorage(type: [String].self, key: "historyKeywords")
        var historyKeywords: [String]
        @AppEnvStorage(type: [QuickSearchWord].self, key: "quickSearchWords")
        var quickSearchWords: [QuickSearchWord]

        func insertGalleries(stored: inout [Gallery], new: [Gallery]) {
            new.forEach { gallery in
                if !stored.contains(gallery) {
                    stored.append(gallery)
                }
            }
        }
        mutating func insertSearchItems(galleries: [Gallery]) {
            insertGalleries(stored: &searchItems, new: galleries)
        }
        mutating func insertFrontpageItems(galleries: [Gallery]) {
            insertGalleries(stored: &frontpageItems, new: galleries)
        }
        mutating func insertWatchedItems(galleries: [Gallery]) {
            insertGalleries(stored: &watchedItems, new: galleries)
        }
        mutating func insertToplistsItems(topIndex: Int, galleries: [Gallery]) {
            galleries.forEach { gallery in
                if toplistsItems[topIndex]?.contains(gallery) == false {
                    toplistsItems[topIndex]?.append(gallery)
                }
            }
        }
        mutating func appendHistoryKeywords(texts: [String]) {
            guard !texts.isEmpty else { return }
            var historyKeywords = historyKeywords

            texts.forEach { text in
                guard !text.isEmpty else { return }
                if let index = historyKeywords.firstIndex(of: text) {
                    if historyKeywords.last != text {
                        historyKeywords.remove(at: index)
                        historyKeywords.append(text)
                    }
                } else {
                    historyKeywords.append(text)
                    let overflow = historyKeywords.count - 15
                    if overflow > 0 {
                        historyKeywords = Array(
                            historyKeywords.dropFirst(overflow)
                        )
                    }
                }
            }
            self.historyKeywords = historyKeywords
        }
        mutating func removeHistoryKeyword(text: String) {
            historyKeywords = historyKeywords.filter { $0 != text }
        }
        mutating func appendQuickSearchWord() {
            quickSearchWords.append(QuickSearchWord(content: ""))
        }
        mutating func deleteQuickSearchWords(offsets: IndexSet) {
            quickSearchWords.remove(atOffsets: offsets)
        }
        mutating func moveQuickSearchWords(source: IndexSet, destination: Int) {
            quickSearchWords.move(fromOffsets: source, toOffset: destination)
        }
        mutating func modifyQuickSearchWord(newWord: QuickSearchWord) {
            if let index = quickSearchWords.firstIndex(
                where: { word in word.id == newWord.id }
            ) { quickSearchWords[index] = newWord }
        }
    }

    // MARK: DetailInfo
    struct DetailInfo {
        var detailLoading = [String: Bool]()
        var detailLoadErrors = [String: AppError]()
        var archiveFundsLoading = false
        var previews = [String: [Int: String]]()
        var previewsLoading = [String: [Int: Bool]]()
        var previewConfig = PreviewConfig.normal(rows: 4)

        var pendingJumpPageIndices = [String: Int]()
        var pendingJumpCommentIDs = [String: String]()

        mutating func fulfillPreviews(gid: String) {
            let galleryState = PersistenceController
                .fetchGalleryStateNonNil(gid: gid)
            previews[gid] = galleryState.previews
        }

        mutating func update(gid: String, previews: [Int: String]) {
            guard !previews.isEmpty else { return }

            if self.previews[gid] == nil {
                self.previews[gid] = [:]
            }
            self.previews[gid] = self.previews[gid]?.merging(
                previews, uniquingKeysWith:
                    { stored, _ in stored }
            )
        }
    }

    // MARK: ContentInfo
    struct ContentInfo {
        var thumbnails = [String: [Int: String]]()
        var mpvKeys = [String: String]()
        var mpvImageKeys = [String: [Int: String]]()
        var mpvReloadTokens = [String: [Int: ReloadToken]]()
        var contents = [String: [Int: String]]()
        var originalContents = [String: [Int: String]]()
        var contentsLoading = [String: [Int: Bool]]()
        var contentsLoadErrors = [String: [Int: AppError]]()

        mutating func fulfillContents(gid: String) {
            let galleryState = PersistenceController.fetchGalleryStateNonNil(gid: gid)
            contents[gid] = galleryState.contents
            originalContents[gid] = galleryState.originalContents
            thumbnails[gid] = galleryState.thumbnails
        }

        func update<T>(
            gid: String, stored: inout [String: [Int: T]],
            new: [Int: T], replaceExisting: Bool = true
        ) {
            guard !new.isEmpty else { return }

            if stored[gid] == nil {
                stored[gid] = [:]
            }
            stored[gid] = stored[gid]?.merging(
                new, uniquingKeysWith: { stored, new in replaceExisting ? new : stored }
            )
        }
        mutating func update(gid: String, thumbnails: [Int: String]) {
            update(gid: gid, stored: &self.thumbnails, new: thumbnails)
        }
        mutating func update(gid: String, contents: [Int: String], originalContents: [Int: String]) {
            update(gid: gid, stored: &self.contents, new: contents)
            update(gid: gid, stored: &self.originalContents, new: originalContents)
        }
    }
}
