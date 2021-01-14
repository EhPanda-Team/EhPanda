//
//  AppState.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

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
    struct Environment {
        var navBarHidden = false
        var homeListType: HomeListType = .frontpage
        var homeViewSheetState: HomeViewSheetState? = nil
        var settingViewSheetState: SettingViewSheetState? = nil
        var settingViewActionSheetState: SettingViewActionSheetState? = nil
        var filterViewActionSheetState: FilterViewActionSheetState? = nil
        var detailViewSheetState: DetailViewSheetState? = nil
        var commentViewSheetState: CommentViewSheetState? = nil
    }
    
    struct Settings {
        @FileStorage(directory: .cachesDirectory, fileName: "user.json")
        var user: User?
        @FileStorage(directory: .cachesDirectory, fileName: "filter.json")
        var filter: Filter?
        @FileStorage(directory: .cachesDirectory, fileName: "setting.json")
        var setting: Setting?
    }
}

extension AppState {
    struct HomeInfo {
        var searchKeyword = ""
        
        var searchItems: [Manga]?
        var searchLoading = false
        var searchNotFound = false
        var searchLoadFailed = false
        var searchCurrentPageNum = 0
        var searchPageNumMaximum = 1
        var moreSearchLoading = false
        
        var frontpageItems: [Manga]?
        var frontpageLoading = false
        var frontpageNotFound = false
        var frontpageLoadFailed = false
        var frontpageCurrentPageNum = 0
        var frontpagePageNumMaximum = 1
        var moreFrontpageLoading = false
        
        var popularItems: [Manga]?
        var popularLoading = false
        var popularNotFound = false
        var popularLoadFailed = false
        
        var favoritesItems: [Manga]?
        var favoritesLoading = false
        var favoritesNotFound = false
        var favoritesLoadFailed = false
        var favoritesCurrentPageNum = 0
        var favoritesPageNumMaximum = 1
        var moreFavoritesLoading = false
        
        func isFavored(id: String) -> Bool {
            if let items = favoritesItems {
                let filteredItems = items
                    .filter { $0.id == id }
                return !filteredItems.isEmpty
            } else {
                return false
            }
        }
        mutating func insertSearchItems(mangas: [Manga]) {
            var historyItems = searchItems
            
            mangas.forEach { manga in
                if historyItems?.contains(manga) == false {
                    historyItems?.append(manga)
                }
            }
            historyItems?.sort {
                $0.publishedDate > $1.publishedDate
            }
            searchItems = historyItems
        }
        mutating func insertFrontpageItems(mangas: [Manga]) {
            var historyItems = frontpageItems
            
            mangas.forEach { manga in
                if historyItems?.contains(manga) == false {
                    historyItems?.append(manga)
                }
            }
            historyItems?.sort {
                $0.publishedDate > $1.publishedDate
            }
            frontpageItems = historyItems
        }
        mutating func insertFavoritesItems(mangas: [Manga]) {
            var historyItems = favoritesItems
            
            mangas.forEach { manga in
                if historyItems?.contains(manga) == false {
                    historyItems?.append(manga)
                }
            }
            historyItems?.sort {
                $0.publishedDate > $1.publishedDate
            }
            favoritesItems = historyItems
        }
    }
    
    struct DetailInfo {
        var commentContent = ""
        
        var mangaDetailLoading = false
        var mangaDetailLoadFailed = false
        
        var alterImagesLoading = false
        
        var mangaCommentsUpdating = false
        var mangaCommentsUpdateFailed = false
    }
    
    struct CommentInfo {
        var commentContent = ""
    }
    
    struct ContentInfo {
        var mangaContentsLoading = false
        var mangaContentsLoadFailed = false
    }
}

extension AppState {
    struct CachedList {
        @FileStorage(directory: .cachesDirectory, fileName: "cachedList.json")
        var items: [String : Manga]?
        
        mutating func cache(items: [Manga]) {
            let previousCount = self.items?.count ?? 0
            if self.items == nil {
                self.items = Dictionary(uniqueKeysWithValues: items.map { ($0.id, $0) })
                return
            }
            
            for item in items {
                if self.items?[item.id] == nil {
                    self.items?[item.id] = item
                }
            }
            let currentCount = self.items?.count ?? 0
            print("キャッシュ済みリスト 更新: \(previousCount) -> \(currentCount)")
        }
        
        mutating func insertDetail(detail: (MangaDetail, String)) {
            self.items?[detail.1]?.detail = detail.0
        }
        mutating func insertAlterImages(images: ([Data], String)) {
            self.items?[images.1]?.detail?.alterImages = images.0
        }
        mutating func updateComments(comments: ([MangaComment], String)) {
            self.items?[comments.1]?.detail?.comments = comments.0
        }
        mutating func insertContents(contents: ([MangaContent], String)) {
            var historyContents = self.items?[contents.1]?.contents
            if historyContents == nil {
                let sortedContents = contents.0.sorted { $0.tag < $1.tag }
                self.items?[contents.1]?.contents = sortedContents
            } else {
                contents.0.forEach { content in
                    if historyContents?.contains(content) == false {
                        historyContents?.append(content)
                    }
                }
                historyContents?.sort { $0.tag < $1.tag }
                self.items?[contents.1]?.contents = historyContents
            }
        }
        mutating func insertReadingProgress(progress: (Int, String)) {
            self.items?[progress.1]?.detail?.readingProgress = progress.0
        }
    }
}

public enum GalleryType: String, Codable {
    case eh = "E-Hentai"
    case ex = "ExHentai"
    
    var abbr: String {
        switch self {
        case .eh:
            return "eh"
        case .ex:
            return "ex"
        }
    }
}
