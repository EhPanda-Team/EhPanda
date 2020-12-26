//
//  AppState.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//


struct AppState {
    var environment = Environment()
    var homeList = HomeList()
}

extension AppState {
    struct Environment {
        var navBarHidden = false
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
        var popularLoadFailed = false
        
        var favoritesItems: [Manga]?
        var favoritesLoading = false
        var favoritesNotFound = false
        var favoritesLoadFailed = false
        
        func displayItems() -> [Manga] {
            return []
        }
    }
}

enum HomeListType: String {
    case search = "検索"
    case popular = "人気"
    case favorites = "お気に入り"
    case downloaded = "ダウンロード済み"
}
