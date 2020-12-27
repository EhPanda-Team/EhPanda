//
//  AppState.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//


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
    }
    
    struct Settings {
        var isWebViewPresented = false
        var isCleanCookiesAlertPresented = false
    }
}

extension AppState {
    struct HomeList {
        var keyword = ""
        var isSettingPresented = false
        var type: HomeListType = .popular
        
        var searchItems: [Manga]?
        var searchLoading = false
        var searchNotFound = false
        var searchLoadFailed = false
        
        var popularItems: [Manga]?
        var popularLoading = false
        var popularNotFound = false
        var popularLoadFailed = false
        
        var favoritesItems: [Manga]?
        var favoritesLoading = false
        var favoritesNotFound = false
        var favoritesLoadFailed = false
    }
    
    struct DetailInfo {
        var mangaDetailLoading = false
        var mangaDetailLoadFailed = false
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
    }
}

enum HomeListType: String {
    case search = "検索"
    case popular = "人気"
    case favorites = "お気に入り"
    case downloaded = "ダウンロード済み"
}
