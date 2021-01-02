//
//  Store.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import Combine

class Store: ObservableObject {
    @Published var appState = AppState()
    
    func dispatch(_ action: AppAction) {
        print("[ACTION]: \(action)")
        let result = reduce(state: appState, action: action)
        appState = result.0
        
        guard let command = result.1 else { return }
        print("[COMMAND]: \(command)")
        command.execute(in: self)
    }
    
    func reduce(state: AppState, action: AppAction) -> (AppState, AppCommand?) {
        var appState = state
        var appCommand: AppCommand?
        
        switch action {
        case .toggleNavBarHidden(let isHidden):
            appState.environment.navBarHidden = isHidden
        case .toggleWebViewPresented:
            appState.settings.isWebViewPresented.toggle()
        case .toggleCleanCookiesAlertPresented:
            appState.settings.isCleanCookiesAlertPresented.toggle()
            
        case .toggleSettingPresented:
            appState.homeList.isSettingPresented.toggle()
        case .toggleHomeListType(let type):
            appState.homeList.type = type
            
        case .fetchSearchItems(let keyword):
            if !didLogin() { break }
            appState.homeList.searchNotFound = false
            appState.homeList.searchLoadFailed = false
            
            if appState.homeList.searchLoading { break }
            appState.homeList.searchLoading = true
            appCommand = FetchSearchItemsCommand(keyword: keyword)
        case .fetchSearchItemsDone(let result):
            appState.homeList.searchLoading = false
            
            switch result {
            case .success(let mangas):
                if mangas.isEmpty {
                    appState.homeList.searchNotFound = true
                } else {
                    appState.homeList.searchItems = mangas
                    appState.cachedList.cache(items: mangas)
                }
            case .failure(let error):
                ePrint(error)
                appState.homeList.searchLoadFailed = true
            }
            
        case .fetchPopularItems:
            if !didLogin() { break }
            appState.homeList.popularNotFound = false
            appState.homeList.popularLoadFailed = false
            
            if appState.homeList.popularLoading { break }
            appState.homeList.popularLoading = true
            appCommand = FetchPopularItemsCommand()
        case .fetchPopularItemsDone(let result):
            appState.homeList.popularLoading = false
            
            switch result {
            case .success(let mangas):
                if mangas.isEmpty {
                    appState.homeList.searchNotFound = true
                } else {
                    appState.homeList.popularItems = mangas
                    appState.cachedList.cache(items: mangas)
                }
            case .failure(let error):
                ePrint(error)
                appState.homeList.popularLoadFailed = true
            }
            
        case .fetchFavoritesItems:
            if !didLogin() { break }
            appState.homeList.favoritesNotFound = false
            appState.homeList.favoritesLoadFailed = false
            
            if appState.homeList.favoritesLoading { break }
            appState.homeList.favoritesLoading = true
            appCommand = FetchFavoritesItemsCommand()
        case .fetchFavoritesItemsDone(result: let result):
            appState.homeList.favoritesLoading = false
            
            switch result {
            case .success(let mangas):
                if mangas.isEmpty {
                    appState.homeList.favoritesNotFound = true
                } else {
                    appState.homeList.favoritesItems = Dictionary(uniqueKeysWithValues: mangas.map { ($0.id, $0)})
                    appState.cachedList.cache(items: mangas)
                }
            case .failure(let error):
                ePrint(error)
                appState.homeList.favoritesLoadFailed = true
            }
            
        case .fetchMangaDetail(id: let id):
            if !didLogin() { break }
            appState.detailInfo.mangaDetailLoadFailed = false
            
            if appState.detailInfo.mangaDetailLoading { break }
            appState.detailInfo.mangaDetailLoading = true
            
            var detailURL = appState.cachedList.items?[id]?.detailURL ?? ""
            detailURL = detailURL + Defaults.URL.detailLarge
            appCommand = FetchMangaDetailCommand(id: id, detailURL: detailURL)
        case .fetchMangaDetailDone(result: let result):
            appState.detailInfo.mangaDetailLoading = false
            
            switch result {
            case .success(let detail):
                appState.cachedList.insertDetail(detail: detail)
            case .failure(let error):
                ePrint(error)
                appState.detailInfo.mangaDetailLoadFailed = true
            }
            
        case .fetchMangaContents(let id):
            appState.contentsInfo.mangaContentsLoadFailed = false
            
            if appState.contentsInfo.mangaContentsLoading { break }
            appState.contentsInfo.mangaContentsLoading = true
            
            let detailURL = appState.cachedList.items?[id]?.detailURL ?? ""
            let pages = Int(appState.cachedList.items?[id]?.detail?.pageCount ?? "") ?? 0
            appCommand = FetchMangaContentsCommand(id: id, pages: pages, detailURL: detailURL)
        case .fetchMangaContentsDone(result: let result):
            appState.contentsInfo.mangaContentsLoading = false
            
            switch result {
            case .success(let contents):
                if contents.0.isEmpty {
                    appState.contentsInfo.mangaContentsLoadFailed = true
                } else {
                    appState.cachedList.insertContents(contents: contents)
                }
            case .failure(let error):
                ePrint(error)
                appState.contentsInfo.mangaContentsLoadFailed = true
            }
        
        case .addFavorite(let id):
            let token = appState.cachedList.items?[id]?.token ?? ""
            appCommand = AddFavoriteCommand(id: id, token: token)
        case .deleteFavorite(let id):
            appCommand = DeleteFavoriteCommand(id: id)
        }
        
        return (appState, appCommand)
    }
}
