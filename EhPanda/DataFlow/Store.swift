//
//  Store.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import SwiftUI
import Combine
import SwiftyBeaver

final class Store: ObservableObject {
    @Published var appState = AppState()

    func dispatch(_ action: AppAction) {
        if appState.environment.isPreview { return }

        let description = String(describing: action)
        if description.contains("error") {
            SwiftyBeaver.error("[ACTION]: " + description)
        } else {
            switch action {
            case .saveAspectBox(let gid, _):
                SwiftyBeaver.verbose("[ACTION]: saveAspectBox(gid: \(gid))")
            case .fetchMangaPreviewsDone(let gid, let pageNumber, let result):
                if case .success(let previews) = result {
                    SwiftyBeaver.verbose(
                        "[ACTION]: fetchMangaPreviewsDone("
                        + "gid: \(gid), "
                        + "pageNumber: \(pageNumber), "
                        + "previews: \(previews.count))"
                    )
                }
            default:
                SwiftyBeaver.verbose("[ACTION]: " + description)
            }
        }
        let result = reduce(state: appState, action: action)
        appState = result.0

        guard let command = result.1 else { return }
        SwiftyBeaver.verbose("[COMMAND]: \(command)")
        command.execute(in: self)
    }

    func reduce(state: AppState, action: AppAction) -> (AppState, AppCommand?) {
        var appState = state
        var appCommand: AppCommand?

        switch action {
        // MARK: App Ops
        case .resetUser:
            appState.settings.user = User()
        case .resetFilters:
            appState.settings.filter = Filter()
        case .saveAspectBox(let gid, let box):
            PersistenceController.update(gid: gid, aspectBox: box)
        case .saveReadingProgress(let gid, let tag):
            PersistenceController.update(gid: gid, readingProgress: tag)
        case .updateDiskImageCacheSize(let size):
            appState.settings.setting.diskImageCacheSize = size
        case .updateAppIconType(let iconType):
            appState.settings.setting.appIconType = iconType
        case .updateHistoryKeywords(let text):
            appState.homeInfo.insertHistoryKeyword(text: text)
        case .clearHistoryKeywords:
            appState.homeInfo.historyKeywords = []
        case .updateSearchKeyword(let text):
            appState.homeInfo.searchKeyword = text
        case .updateViewControllersCount:
            appState.environment.viewControllersCount = viewControllersCount
        case .replaceMangaCommentJumpID(let gid):
            appState.environment.mangaItemReverseID = gid
        case .updateIsSlideMenuClosed(let isClosed):
            appState.environment.isSlideMenuClosed = isClosed

        // MARK: App Env
        case .toggleApp(let unlocked):
            appState.environment.isAppUnlocked = unlocked
        case .toggleBlur(let effectOn):
            withAnimation(.linear(duration: 0.1)) {
                appState.environment.blurRadius = effectOn ? 10 : 0
            }
        case .toggleHomeList(let type):
            appState.environment.homeListType = type
        case .toggleFavorite(let index):
            appState.environment.favoritesIndex = index
        case .toggleNavBar(let hidden):
            appState.environment.navBarHidden = hidden
        case .toggleHomeViewSheet(let state):
            if state != nil { impactFeedback(style: .light) }
            appState.environment.homeViewSheetState = state
        case .toggleSettingViewSheet(let state):
            if state != nil { impactFeedback(style: .light) }
            appState.environment.settingViewSheetState = state
        case .toggleSettingViewActionSheet(let state):
            appState.environment.settingViewActionSheetState = state
        case .toggleFilterViewActionSheet(let state):
            appState.environment.filterViewActionSheetState = state
        case .toggleDetailViewSheet(let state):
            if state != nil { impactFeedback(style: .light) }
            appState.environment.detailViewSheetState = state
        case .toggleCommentViewSheet(let state):
            if state != nil { impactFeedback(style: .light) }
            appState.environment.commentViewSheetState = state

        // MARK: Fetch Data
        case .fetchGreeting:
            if appState.settings.greetingLoading { break }
            appState.settings.greetingLoading = true

            appCommand = FetchGreetingCommand()
        case .fetchGreetingDone(let result):
            appState.settings.greetingLoading = false

            switch result {
            case .success(let greeting):
                appState.settings.insert(greeting: greeting)
            case .failure(let error):
                if error == .parseFailed {
                    var greeting = Greeting()
                    greeting.updateTime = Date()
                    appState.settings.insert(greeting: greeting)
                }
            }

        case .fetchUserInfo:
            let uid = appState.settings.user.apiuid
            guard !uid.isEmpty, !appState.settings.userInfoLoading
            else { break }
            appState.settings.userInfoLoading = true

            appCommand = FetchUserInfoCommand(uid: uid)
        case .fetchUserInfoDone(let result):
            appState.settings.userInfoLoading = false

            if case .success(let user) = result {
                appState.settings.update(user: user)
            }

        case .fetchFavoriteNames:
            if appState.settings.favoriteNamesLoading { break }
            appState.settings.favoriteNamesLoading = true

            appCommand = FetchFavoriteNamesCommand()
        case .fetchFavoriteNamesDone(let result):
            appState.settings.favoriteNamesLoading = false

            if case .success(let names) = result {
                appState.settings.user.favoriteNames = names
            }

        case .fetchMangaItemReverse(var detailURL):
            appState.environment.mangaItemReverseLoadFailed = false

            if appState.environment.mangaItemReverseLoading { break }
            appState.environment.mangaItemReverseLoading = true

            if appState.settings.setting.redirectsLinksToSelectedHost {
                detailURL = detailURL.replacingOccurrences(
                    of: Defaults.URL.ehentai,
                    with: Defaults.URL.host
                )
                .replacingOccurrences(
                    of: Defaults.URL.exhentai,
                    with: Defaults.URL.host
                )
            }
            appCommand = FetchMangaItemReverseCommand(detailURL: detailURL)
        case .fetchMangaItemReverseDone(let result):
            appState.environment.mangaItemReverseLoading = false

            switch result {
            case .success(let manga):
                PersistenceController.add(mangas: [manga])
                appState.environment.mangaItemReverseID = manga.gid
            case .failure:
                appState.environment.mangaItemReverseLoadFailed = true
            }

        case .fetchSearchItems(let keyword):
            appState.homeInfo.searchNotFound = false
            appState.homeInfo.searchLoadFailed = false

            if appState.homeInfo.searchLoading { break }
            appState.homeInfo.searchCurrentPageNum = 0
            appState.homeInfo.searchLoading = true

            let filter = appState.settings.filter
            appCommand = FetchSearchItemsCommand(keyword: keyword, filter: filter)
        case .fetchSearchItemsDone(let result):
            appState.homeInfo.searchLoading = false

            switch result {
            case .success(let mangas):
                appState.homeInfo.searchCurrentPageNum = mangas.1.current
                appState.homeInfo.searchPageNumMaximum = mangas.1.maximum

                appState.homeInfo.searchItems = mangas.2
                if mangas.2.isEmpty {
                    if mangas.1.current < mangas.1.maximum {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            self?.dispatch(.fetchMoreSearchItems(keyword: mangas.0))
                        }
                    } else {
                        appState.homeInfo.searchNotFound = true
                    }
                } else {
                    PersistenceController.add(mangas: mangas.2)
                }
            case .failure:
                appState.homeInfo.searchLoadFailed = true
            }

        case .fetchMoreSearchItems(let keyword):
            appState.homeInfo.moreSearchLoadFailed = false

            let currentNum = appState.homeInfo.searchCurrentPageNum
            let maximumNum = appState.homeInfo.searchPageNumMaximum
            if currentNum + 1 > maximumNum { break }

            if appState.homeInfo.moreSearchLoading { break }
            appState.homeInfo.moreSearchLoading = true

            let filter = appState.settings.filter
            let lastID = appState.homeInfo.searchItems?.last?.id ?? ""
            let pageNum = appState.homeInfo.searchCurrentPageNum + 1
            appCommand = FetchMoreSearchItemsCommand(
                keyword: keyword,
                filter: filter,
                lastID: lastID,
                pageNum: pageNum
            )
        case .fetchMoreSearchItemsDone(let result):
            appState.homeInfo.moreSearchLoading = false

            switch result {
            case .success(let mangas):
                appState.homeInfo.searchCurrentPageNum = mangas.1.current
                appState.homeInfo.searchPageNumMaximum = mangas.1.maximum

                appState.homeInfo.insertSearchItems(mangas: mangas.2)
                PersistenceController.add(mangas: mangas.2)

                if mangas.1.current < mangas.1.maximum && mangas.2.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.dispatch(.fetchMoreSearchItems(keyword: mangas.0))
                    }
                } else if appState.homeInfo.searchItems?.isEmpty == true {
                    appState.homeInfo.searchNotFound = true
                }
            case .failure:
                appState.homeInfo.moreSearchLoadFailed = true
            }

        case .fetchFrontpageItems:
            appState.homeInfo.frontpageNotFound = false
            appState.homeInfo.frontpageLoadFailed = false

            if appState.homeInfo.frontpageLoading { break }
            appState.homeInfo.frontpageCurrentPageNum = 0
            appState.homeInfo.frontpageLoading = true
            appCommand = FetchFrontpageItemsCommand()
        case .fetchFrontpageItemsDone(let result):
            appState.homeInfo.frontpageLoading = false

            switch result {
            case .success(let mangas):
                appState.homeInfo.frontpageCurrentPageNum = mangas.0.current
                appState.homeInfo.frontpagePageNumMaximum = mangas.0.maximum

                appState.homeInfo.frontpageItems = mangas.1
                if mangas.1.isEmpty {
                    if mangas.0.current < mangas.0.maximum {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            self?.dispatch(.fetchMoreFrontpageItems)
                        }
                    } else {
                        appState.homeInfo.frontpageNotFound = true
                    }
                } else {
                    PersistenceController.add(mangas: mangas.1)
                }
            case .failure:
                appState.homeInfo.frontpageLoadFailed = true
            }

        case .fetchMoreFrontpageItems:
            appState.homeInfo.moreFrontpageLoadFailed = false

            let currentNum = appState.homeInfo.frontpageCurrentPageNum
            let maximumNum = appState.homeInfo.frontpagePageNumMaximum
            if currentNum + 1 > maximumNum { break }

            if appState.homeInfo.moreFrontpageLoading { break }
            appState.homeInfo.moreFrontpageLoading = true

            let lastID = appState.homeInfo.frontpageItems?.last?.id ?? ""
            let pageNum = appState.homeInfo.frontpageCurrentPageNum + 1
            appCommand = FetchMoreFrontpageItemsCommand(lastID: lastID, pageNum: pageNum)
        case .fetchMoreFrontpageItemsDone(let result):
            appState.homeInfo.moreFrontpageLoading = false

            switch result {
            case .success(let mangas):
                appState.homeInfo.frontpageCurrentPageNum = mangas.0.current
                appState.homeInfo.frontpagePageNumMaximum = mangas.0.maximum

                appState.homeInfo.insertFrontpageItems(mangas: mangas.1)
                PersistenceController.add(mangas: mangas.1)

                if mangas.0.current < mangas.0.maximum && mangas.1.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.dispatch(.fetchMoreFrontpageItems)
                    }
                } else if appState.homeInfo.frontpageItems?.isEmpty == true {
                    appState.homeInfo.frontpageNotFound = true
                }
            case .failure:
                appState.homeInfo.moreFrontpageLoadFailed = true
            }

        case .fetchPopularItems:
            appState.homeInfo.popularNotFound = false
            appState.homeInfo.popularLoadFailed = false

            if appState.homeInfo.popularLoading { break }
            appState.homeInfo.popularLoading = true
            appCommand = FetchPopularItemsCommand()
        case .fetchPopularItemsDone(let result):
            appState.homeInfo.popularLoading = false

            switch result {
            case .success(let mangas):
                if mangas.1.isEmpty {
                    appState.homeInfo.popularNotFound = true
                } else {
                    appState.homeInfo.popularItems = mangas.1
                    PersistenceController.add(mangas: mangas.1)
                }
            case .failure:
                appState.homeInfo.popularLoadFailed = true
            }

        case .fetchWatchedItems:
            appState.homeInfo.watchedNotFound = false
            appState.homeInfo.watchedLoadFailed = false

            if appState.homeInfo.watchedLoading { break }
            appState.homeInfo.watchedCurrentPageNum = 0
            appState.homeInfo.watchedLoading = true
            appCommand = FetchWatchedItemsCommand()
        case .fetchWatchedItemsDone(let result):
            appState.homeInfo.watchedLoading = false

            switch result {
            case .success(let mangas):
                appState.homeInfo.watchedCurrentPageNum = mangas.0.current
                appState.homeInfo.watchedPageNumMaximum = mangas.0.maximum

                appState.homeInfo.watchedItems = mangas.1
                if mangas.1.isEmpty {
                    if mangas.0.current < mangas.0.maximum {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            self?.dispatch(.fetchMoreWatchedItems)
                        }
                    } else {
                        appState.homeInfo.watchedNotFound = true
                    }
                } else {
                    PersistenceController.add(mangas: mangas.1)
                }
            case .failure:
                appState.homeInfo.watchedLoadFailed = true
            }

        case .fetchMoreWatchedItems:
            appState.homeInfo.moreWatchedLoadFailed = false

            let currentNum = appState.homeInfo.watchedCurrentPageNum
            let maximumNum = appState.homeInfo.watchedPageNumMaximum
            if currentNum + 1 > maximumNum { break }

            if appState.homeInfo.moreWatchedLoading { break }
            appState.homeInfo.moreWatchedLoading = true

            let lastID = appState.homeInfo.watchedItems?.last?.id ?? ""
            let pageNum = appState.homeInfo.watchedCurrentPageNum + 1
            appCommand = FetchMoreWatchedItemsCommand(lastID: lastID, pageNum: pageNum)
        case .fetchMoreWatchedItemsDone(let result):
            appState.homeInfo.moreWatchedLoading = false

            switch result {
            case .success(let mangas):
                appState.homeInfo.watchedCurrentPageNum = mangas.0.current
                appState.homeInfo.watchedPageNumMaximum = mangas.0.maximum

                appState.homeInfo.insertWatchedItems(mangas: mangas.1)
                PersistenceController.add(mangas: mangas.1)

                if mangas.0.current < mangas.0.maximum && mangas.1.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.dispatch(.fetchMoreWatchedItems)
                    }
                } else if appState.homeInfo.watchedItems?.isEmpty == true {
                    appState.homeInfo.watchedNotFound = true
                }
            case .failure:
                appState.homeInfo.moreWatchedLoadFailed = true
            }

        case .fetchFavoritesItems(let favIndex):
            appState.homeInfo.favoritesNotFound[favIndex] = false
            appState.homeInfo.favoritesLoadFailed[favIndex] = false

            if appState.homeInfo.favoritesLoading[favIndex] != false { break }
            appState.homeInfo.favoritesCurrentPageNum[favIndex] = 0
            appState.homeInfo.favoritesLoading[favIndex] = true
            appCommand = FetchFavoritesItemsCommand(favIndex: favIndex)
        case .fetchFavoritesItemsDone(let carriedValue, let result):
            appState.homeInfo.favoritesLoading[carriedValue] = false

            switch result {
            case .success(let mangas):
                appState.homeInfo.favoritesCurrentPageNum[carriedValue] = mangas.0.current
                appState.homeInfo.favoritesPageNumMaximum[carriedValue] = mangas.0.maximum

                appState.homeInfo.favoritesItems[carriedValue] = mangas.1
                if mangas.1.isEmpty {
                    if mangas.0.current < mangas.0.maximum {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            self?.dispatch(.fetchMoreFavoritesItems(index: carriedValue))
                        }
                    } else {
                        appState.homeInfo.favoritesNotFound[carriedValue] = true
                    }
                } else {
                    PersistenceController.add(mangas: mangas.1)
                }
            case .failure:
                appState.homeInfo.favoritesLoadFailed[carriedValue] = true
            }

        case .fetchMoreFavoritesItems(let favIndex):
            appState.homeInfo.moreFavoritesLoadFailed[favIndex] = false

            let currentNum = appState.homeInfo.favoritesCurrentPageNum[favIndex]
            let maximumNum = appState.homeInfo.favoritesPageNumMaximum[favIndex]
            if (currentNum ?? 0) + 1 >= maximumNum ?? 1 { break }

            if appState.homeInfo.moreFavoritesLoading[favIndex] != false { break }
            appState.homeInfo.moreFavoritesLoading[favIndex] = true

            let lastID = appState.homeInfo.favoritesItems[favIndex]?.last?.id ?? ""
            let pageNum = (appState.homeInfo.favoritesCurrentPageNum[favIndex] ?? 0) + 1
            appCommand = FetchMoreFavoritesItemsCommand(
                favIndex: favIndex,
                lastID: lastID,
                pageNum: pageNum
            )
        case .fetchMoreFavoritesItemsDone(let carriedValue, let result):
            appState.homeInfo.moreFavoritesLoading[carriedValue] = false

            switch result {
            case .success(let mangas):
                appState.homeInfo.favoritesCurrentPageNum[carriedValue] = mangas.0.current
                appState.homeInfo.favoritesPageNumMaximum[carriedValue] = mangas.0.maximum

                appState.homeInfo.insertFavoritesItems(favIndex: carriedValue, mangas: mangas.1)
                PersistenceController.add(mangas: mangas.1)

                if mangas.0.current < mangas.0.maximum && mangas.1.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.dispatch(.fetchMoreFavoritesItems(index: carriedValue))
                    }
                } else if appState.homeInfo.favoritesItems[carriedValue]?.isEmpty == true {
                    appState.homeInfo.favoritesNotFound[carriedValue] = true
                }
            case .failure:
                appState.homeInfo.moreFavoritesLoading[carriedValue] = true
            }

        case .fetchMangaDetail(let gid):
            appState.detailInfo.detailLoadFailed[gid] = false

            if appState.detailInfo.detailLoading[gid] == true { break }
            appState.detailInfo.detailLoading[gid] = true

            let detailURL = PersistenceController.fetchManga(gid: gid)?.detailURL ?? ""
            appCommand = FetchMangaDetailCommand(gid: gid, detailURL: detailURL)
        case .fetchMangaDetailDone(let gid, let result):
            appState.detailInfo.detailLoading[gid] = false

            switch result {
            case .success(let detail):
                if let apikey = detail.2 {
                    appState.settings.user.apikey = apikey
                }
                if let previewConfig = detail.1.previewConfig {
                    appState.detailInfo.previewConfig = previewConfig
                }
                PersistenceController.add(detail: detail.0)
                PersistenceController.update(fetchedState: detail.1)
            case .failure:
                appState.detailInfo.detailLoadFailed[gid] = true
            }

        case .fetchMangaArchiveFunds(let gid):
            if appState.detailInfo.archiveFundsLoading { break }
            appState.detailInfo.archiveFundsLoading = true
            let detailURL = PersistenceController.fetchManga(gid: gid)?.detailURL ?? ""
            appCommand = FetchMangaArchiveFundsCommand(gid: gid, detailURL: detailURL)
        case .fetchMangaArchiveFundsDone(let result):
            appState.detailInfo.archiveFundsLoading = false

            if case .success(let funds) = result {
                appState.settings.update(
                    user: User(
                        currentGP: funds.0,
                        currentCredits: funds.1
                    )
                )
            }

        case .fetchMangaPreviews(let gid, let index):
            let pageNumber = index / appState.detailInfo.previewConfig.batchSize
            if appState.detailInfo.previewsLoading[gid] == nil {
                appState.detailInfo.previewsLoading[gid] = [:]
            }

            if appState.detailInfo.previewsLoading[gid]?[pageNumber] == true { break }
            appState.detailInfo.previewsLoading[gid]?[pageNumber] = true

            let detailURL = PersistenceController.fetchManga(gid: gid)?.detailURL ?? ""
            let url = Defaults.URL.detailPage(url: detailURL, pageNum: pageNumber)
            appCommand = FetchMangaPreviewsCommand(gid: gid, url: url, pageNumber: pageNumber)

        case .fetchMangaPreviewsDone(let gid, let pageNumber, let result):
            appState.detailInfo.previewsLoading[gid]?[pageNumber] = false

            switch result {
            case .success(let previews):
                PersistenceController.update(fetchedState: MangaState(gid: gid, previews: previews))
            case .failure(let error):
                SwiftyBeaver.error(error)
            }

        case .fetchMangaContents(let gid, let index):
            let pageNumber = index / appState.detailInfo.previewConfig.batchSize
            if appState.contentInfo.contentsLoading[gid] == nil {
                appState.contentInfo.contentsLoading[gid] = [:]
            }
            if appState.contentInfo.contentsLoadFailed[gid] == nil {
                appState.contentInfo.contentsLoadFailed[gid] = [:]
            }
            appState.contentInfo.contentsLoadFailed[gid]?[pageNumber] = false

            if appState.contentInfo.contentsLoading[gid]?[pageNumber] == true { break }
            appState.contentInfo.contentsLoading[gid]?[pageNumber] = true

            let detailURL = PersistenceController.fetchManga(gid: gid)?.detailURL ?? ""
            let url = Defaults.URL.detailPage(url: detailURL, pageNum: pageNumber)
            appCommand = FetchMangaContentsCommand(gid: gid, url: url, pageNumber: pageNumber)
        case .fetchMangaContentsDone(let gid, let pageNumber, let result):
            appState.contentInfo.contentsLoading[gid]?[pageNumber] = false

            switch result {
            case .success(let contents):
                PersistenceController.update(gid: gid, contents: contents)
            case .failure:
                appState.contentInfo.contentsLoadFailed[gid]?[pageNumber] = true
            }

        // MARK: Account Ops
        case .createProfile:
            appCommand = CreateProfileCommand()
        case .verifyProfile:
            appCommand = VerifyProfileCommand()
        case .verifyProfileDone(let result):
            switch result {
            case .success((let profileValue, let profileNotFound)):
                if let profileValue = profileValue {
                    let profileValueString = String(profileValue)
                    let hostURL = Defaults.URL.host.safeURL()
                    let selectedProfileKey = "sp"

                    let cookieValue = getCookieValue(
                        url: hostURL, key: selectedProfileKey
                    )
                    if cookieValue.rawValue != profileValueString {
                        setCookie(
                            url: hostURL,
                            key: selectedProfileKey,
                            value: profileValueString
                        )
                    }
                } else if profileNotFound {
                    dispatch(.createProfile)
                } else {
                    SwiftyBeaver.error("Found profile but failed in parsing value.")
                }
            case .failure(let error):
                SwiftyBeaver.error(error)
            }
        case .addFavorite(let gid, let favIndex):
            let token = PersistenceController.fetchManga(gid: gid)?.token ?? ""
            appCommand = AddFavoriteCommand(gid: gid, token: token, favIndex: favIndex)
        case .deleteFavorite(let gid):
            appCommand = DeleteFavoriteCommand(gid: gid)

        case .rate(let gid, let rating):
            let apiuidString = appState.settings.user.apiuid
            guard !apiuidString.isEmpty,
                  let apikey = appState.settings.user.apikey,
                  let token = PersistenceController.fetchManga(gid: gid)?.token,
                  let apiuid = Int(apiuidString),
                  let gid = Int(gid)
            else { break }

            appCommand = RateCommand(
                apiuid: apiuid,
                apikey: apikey,
                gid: gid,
                token: token,
                rating: rating
            )

        case .comment(let gid, let content):
            let detailURL = PersistenceController.fetchManga(gid: gid)?.detailURL ?? ""
            appCommand = CommentCommand(gid: gid, content: content, detailURL: detailURL)
        case .editComment(let gid, let commentID, let content):
            let detailURL = PersistenceController.fetchManga(gid: gid)?.detailURL ?? ""

            appCommand = EditCommentCommand(
                gid: gid,
                commentID: commentID,
                content: content,
                detailURL: detailURL
            )
        case .voteComment(let gid, let commentID, let vote):
            let apiuidString = appState.settings.user.apiuid
            guard !apiuidString.isEmpty,
                  let apikey = appState.settings.user.apikey,
                  let token = PersistenceController.fetchManga(gid: gid)?.token,
                  let commentID = Int(commentID),
                  let apiuid = Int(apiuidString),
                  let gid = Int(gid)
            else { break }

            appCommand = VoteCommentCommand(
                apiuid: apiuid,
                apikey: apikey,
                gid: gid,
                token: token,
                commentID: commentID,
                commentVote: vote
            )
        }

        return (appState, appCommand)
    }
}
