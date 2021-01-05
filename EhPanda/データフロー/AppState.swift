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
    var homeList = HomeList()
    var detailInfo = DetailInfo()
    var contentsInfo = ContentsInfo()
    var cachedList = CachedList()
}

extension AppState {
    struct Environment {
        var navBarHidden = false
        var isWebViewPresented = false
        var isSettingPresented = false
        var isCleanCookiesAlertPresented = false
    }
    
    struct Settings {
        @FileStorage(directory: .cachesDirectory, fileName: "user.json")
        var user: User?
        var galleryType: GalleryType {
            get {
                let rawValue = UserDefaults
                    .standard
                    .string(forKey: "GalleryType")
                    ?? "E-Hentai"
                return GalleryType(rawValue: rawValue)!
            }
            
            set {
                UserDefaults
                    .standard
                    .set(newValue.rawValue,
                         forKey: "GalleryType")
            }
        }
    }
}

extension AppState {
    struct HomeList {
        var keyword = ""
        var type: HomeListType = .popular
        var searchItems: [Manga]?
        var searchLoading = false
        var searchNotFound = false
        var searchLoadFailed = false
        
        var popularItems: [Manga]?
        var popularLoading = false
        var popularNotFound = false
        var popularLoadFailed = false
        
        var favoritesItems: [String : Manga]?
        var favoritesLoading = false
        var favoritesNotFound = false
        var favoritesLoadFailed = false
        
        func isFavored(id: String) -> Bool {
            favoritesItems?[id] != nil
        }
    }
    
    struct DetailInfo {
        var commentContent_Button = ""
        var commentContent_BarItem = ""
        var isDraftCommentViewPresented_Button = false
        var isDraftCommentViewPresented_BarItem = false
        
        var mangaDetailLoading = false
        var mangaDetailLoadFailed = false
        
        var alterImagesLoading = false
        
        var mangaCommentsUpdating = false
        var mangaCommentsUpdateFailed = false
    }
    
    struct ContentsInfo {
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
            print("CachedList updated: \(previousCount) to \(currentCount)")
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
                self.items?[contents.1]?.contents = contents.0
            } else {
                historyContents?.append(contentsOf: contents.0)
                historyContents?.sort { $0.tag < $1.tag }
                self.items?[contents.1]?.contents = historyContents
            }
        }
    }
}

enum HomeListType: String {
    case search = "検索"
    case popular = "人気"
    case favorites = "お気に入り"
    case downloaded = "ダウンロード済み"
}

public enum GalleryType: String, Codable {
    case eh = "E-Hentai"
    case ex = "ExHentai"
}
