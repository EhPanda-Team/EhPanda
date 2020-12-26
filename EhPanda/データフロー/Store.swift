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
        case .toggleSettingPresented:
            appState.homeList.isSettingPresented.toggle()
        case .toggleHomeListType(let type):
            appState.homeList.type = type
            
        case .fetchSearchItems(let keyword):
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
                }
            case .failure(let error):
                ePrint(error)
                appState.homeList.searchLoadFailed = true
            }
            
        case .fetchPopularItems:
            appState.homeList.popularLoadFailed = false
            
            if appState.homeList.popularLoading { break }
            appState.homeList.popularLoading = true
            appCommand = FetchPopularItemsCommand()
        case .fetchPopularItemsDone(let result):
            appState.homeList.popularLoading = false
            
            switch result {
            case .success(let mangas):
                appState.homeList.popularItems = mangas
            case .failure(let error):
                ePrint(error)
                appState.homeList.popularLoadFailed = true
            }
        }
        
        return (appState, appCommand)
    }
}
