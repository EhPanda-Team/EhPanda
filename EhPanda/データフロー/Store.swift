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
        case .updateUser(let user):
            appState.settings.user = user
        case .eraseCachedList:
            appState.cachedList.items = nil
        case .initiateFilter:
            appState.settings.filter = Filter()
        case .initiateSetting:
            appState.settings.setting = Setting()
        case .saveReadingProgress(let id, let tag):
            appState.cachedList.insertReadingProgress(progress: (tag, id))
            
        case .toggleHomeListType(let type):
            appState.environment.homeListType = type
        case .toggleNavBarHidden(let isHidden):
            appState.environment.navBarHidden = isHidden
        case .toggleHomeViewSheetState(let state):
            appState.environment.homeViewSheetState = state
        case .toggleSettingViewActionSheetState(let state):
            appState.environment.settingViewActionSheetState = state
        case .toggleFilterViewActionSheetState(let state):
            appState.environment.filterViewActionSheetState = state
        case .toggleDetailViewSheetState(let state):
            appState.environment.detailViewSheetState = state
        case .toggleDetailViewSheetNil:
            appState.environment.detailViewSheetState = nil
        case .toggleCommentViewSheetState(let state):
            appState.environment.commentViewSheetState = state
        case .toggleCommentViewSheetNil:
            appState.environment.commentViewSheetState = nil
            
        case .cleanDetailViewCommentContent:
            appState.detailInfo.commentContent = ""
        case .cleanCommentViewCommentContent:
            appState.commentInfo.commentContent = ""
            
        case .fetchSearchItems(let keyword):
            if !didLogin() && exx { break }
            appState.homeInfo.searchNotFound = false
            appState.homeInfo.searchLoadFailed = false
            
            if appState.homeInfo.searchLoading { break }
            appState.homeInfo.searchLoading = true
            
            let filter = appState.settings.filter ?? Filter()
            appCommand = FetchSearchItemsCommand(keyword: keyword, filter: filter)
        case .fetchSearchItemsDone(let result):
            appState.homeInfo.searchLoading = false
            
            switch result {
            case .success(let mangas):
                if mangas.isEmpty {
                    appState.homeInfo.searchNotFound = true
                } else {
                    appState.homeInfo.searchItems = mangas
                    appState.cachedList.cache(items: mangas)
                }
            case .failure(let error):
                ePrint(error)
                appState.homeInfo.searchLoadFailed = true
            }
            
        case .fetchFrontpageItems:
            if !didLogin() && exx { break }
            appState.homeInfo.frontpageNotFound = false
            appState.homeInfo.frontpageLoadFailed = false
            
            if appState.homeInfo.frontpageLoading { break }
            appState.homeInfo.frontpageLoading = true
            appCommand = FetchFrontpageItemsCommand()
        case .fetchFrontpageItemsDone(let result):
            appState.homeInfo.frontpageLoading = false
            
            switch result {
            case .success(let mangas):
                if mangas.isEmpty {
                    appState.homeInfo.frontpageNotFound = true
                } else {
                    appState.homeInfo.frontpageItems = mangas
                    appState.cachedList.cache(items: mangas)
                }
            case .failure(let error):
                ePrint(error)
                appState.homeInfo.frontpageLoadFailed = true
            }
            
        case .fetchPopularItems:
            if !didLogin() && exx { break }
            appState.homeInfo.popularNotFound = false
            appState.homeInfo.popularLoadFailed = false
            
            if appState.homeInfo.popularLoading { break }
            appState.homeInfo.popularLoading = true
            appCommand = FetchPopularItemsCommand()
        case .fetchPopularItemsDone(let result):
            appState.homeInfo.popularLoading = false
            
            switch result {
            case .success(let mangas):
                if mangas.isEmpty {
                    appState.homeInfo.popularNotFound = true
                } else {
                    appState.homeInfo.popularItems = mangas
                    appState.cachedList.cache(items: mangas)
                }
            case .failure(let error):
                ePrint(error)
                appState.homeInfo.popularLoadFailed = true
            }
            
        case .fetchFavoritesItems:
            if !didLogin() && exx { break }
            appState.homeInfo.favoritesNotFound = false
            appState.homeInfo.favoritesLoadFailed = false
            
            if appState.homeInfo.favoritesLoading { break }
            appState.homeInfo.favoritesLoading = true
            appCommand = FetchFavoritesItemsCommand()
        case .fetchFavoritesItemsDone(result: let result):
            appState.homeInfo.favoritesLoading = false
            
            switch result {
            case .success(let mangas):
                if mangas.isEmpty {
                    appState.homeInfo.favoritesNotFound = true
                } else {
                    appState.homeInfo.favoritesItems = Dictionary(
                        uniqueKeysWithValues: mangas.map { ($0.id, $0)}
                    )
                    appState.cachedList.cache(items: mangas)
                }
            case .failure(let error):
                ePrint(error)
                appState.homeInfo.favoritesLoadFailed = true
            }
            
        case .fetchMangaDetail(id: let id):
            if !didLogin() && exx { break }
            appState.detailInfo.mangaDetailLoadFailed = false
            
            if appState.detailInfo.mangaDetailLoading { break }
            appState.detailInfo.mangaDetailLoading = true
            
            let detailURL = appState.cachedList.items?[id]?.detailURL ?? ""
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
        case .fetchAlterImages(let id, let doc):
            if appState.detailInfo.alterImagesLoading { break }
            appState.detailInfo.alterImagesLoading = true
            
            appCommand = FetchAlterImagesCommand(id: id, doc: doc)
        case .fetchAlterImagesDone(result: let result):
            appState.detailInfo.alterImagesLoading = false
            
            switch result {
            case .success(let images):
                appState.cachedList.insertAlterImages(images: images)
            default:
                print("")
            }
            
        case .updateMangaComments(id: let id):
            appState.detailInfo.mangaCommentsUpdateFailed = false
            
            if appState.detailInfo.mangaCommentsUpdating { break }
            appState.detailInfo.mangaCommentsUpdating = true
            
            let detailURL = appState.cachedList.items?[id]?.detailURL ?? ""
            appCommand = UpdateMangaCommentsCommand(id: id, detailURL: detailURL)
        case .updateMangaCommentsDone(result: let result):
            appState.detailInfo.mangaCommentsUpdating = false
            
            switch result {
            case .success(let comments):
                appState.cachedList.updateComments(comments: comments)
            case .failure(let error):
                ePrint(error)
                appState.detailInfo.mangaCommentsUpdateFailed = true
            }
            
        case .fetchMangaContents(let id):
            appState.contentInfo.mangaContentsLoadFailed = false
            
            if appState.contentInfo.mangaContentsLoading { break }
            appState.contentInfo.mangaContentsLoading = true
            
            let detailURL = appState.cachedList.items?[id]?.detailURL ?? ""
            let pages = Int(appState.cachedList.items?[id]?.detail?.pageCount ?? "") ?? 0
            appCommand = FetchMangaContentsCommand(id: id, pages: pages, detailURL: detailURL)
        case .fetchMangaContentsDone(result: let result):
            appState.contentInfo.mangaContentsLoading = false
            
            switch result {
            case .success(let contents):
                if contents.0.isEmpty {
                    appState.contentInfo.mangaContentsLoadFailed = true
                } else {
                    appState.cachedList.insertContents(contents: contents)
                }
            case .failure(let error):
                ePrint(error)
                appState.contentInfo.mangaContentsLoadFailed = true
            }
        
        case .addFavorite(let id):
            let token = appState.cachedList.items?[id]?.token ?? ""
            appCommand = AddFavoriteCommand(id: id, token: token)
        case .deleteFavorite(let id):
            appCommand = DeleteFavoriteCommand(id: id)
            
        case .comment(let id, let content):
            let detailURL = appState.cachedList.items?[id]?.detailURL ?? ""
            appCommand = CommentCommand(id: id, content: content, detailURL: detailURL)
        case .editComment(let id, let commentID, let content):
            let detailURL = appState.cachedList.items?[id]?.detailURL ?? ""
            
            appCommand = EditCommentCommand(
                id: id,
                commentID: commentID,
                content: content,
                detailURL: detailURL
            )
        case .voteComment(let id, let commentID, let vote):
            guard let apiuidString = appState.settings.user?.apiuid,
                  let apikey = appState.settings.user?.apikey,
                  let token = appState.cachedList.items?[id]?.token,
                  let commentID = Int(commentID),
                  let apiuid = Int(apiuidString),
                  let id = Int(id)
            else { break }
            
            appCommand = VoteCommentCommand(
                apiuid: apiuid,
                apikey: apikey,
                gid: id,
                token: token,
                commentID: commentID,
                commentVote: vote
            )
        }
        
        return (appState, appCommand)
    }
}
