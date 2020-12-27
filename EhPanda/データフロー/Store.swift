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
            
//        case .fetchMangaContents(id: let id):
//            if appState.contentsInfo.mangaContentsLoading { break }
//            appState.contentsInfo.mangaContentsLoading = true
//            
//            let detailURL = appState.cachedList.items?[id]?.detailURL ?? ""
//            appCommand = FetchMangaPreviewsCommand(id: id, detailURL: detailURL)
//        case .fetchMangaContentsDone(result: let result):
//            appState.contentsInfo.mangaContentsLoading = false
//            
//            switch result {
//            case .success(let previews):
//                appState.cachedList.insertPreviews(previews: previews)
//            case .failure(let error):
//                ePrint(error)
//                appState.contentsInfo.mangaContentsLoadFailed = true
//            }
        }
        
        return (appState, appCommand)
    }
}
