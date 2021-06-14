//
//  Store.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import SwiftUI
import Combine

final class Store: ObservableObject {
    @Published var appState = AppState()

    func dispatch(_ action: AppAction) {
        if appState.environment.isPreview { return }

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
        // MARK: App Ops
        case .replaceUser(let user):
            appState.settings.user = user
        case .clearCachedList:
            appState.cachedList.items = nil
        case .clearHistoryItems:
            appState.homeInfo.historyItems = nil
        case .initializeStates:
            if appState.settings.user == nil {
                appState.settings.user = User()
            }
            if appState.settings.filter == nil {
                appState.settings.filter = Filter()
            }
            if appState.settings.setting == nil {
                appState.settings.setting = Setting()
            }
            // swiftlint:disable unneeded_break_in_switch
            break
            // swiftlint:enable unneeded_break_in_switch
        case .initializeFilter:
            appState.settings.filter = Filter()
        case .saveAspectBox(let gid, let box):
            appState.cachedList.insertAspectBox(gid: gid, box: box)
        case .saveReadingProgress(let gid, let tag):
            appState.cachedList.insertReadingProgress(gid: gid, progress: tag)
        case .updateDiskImageCacheSize(let size):
            appState.settings.setting?.diskImageCacheSize = size
        case .updateAppIconType(let iconType):
            appState.settings.setting?.appIconType = iconType
        case .updateHistoryItems(let gid):
            let item = appState.cachedList.items?[gid]
            appState.homeInfo.insertHistoryItem(manga: item)
        case .updateHistoryKeywords(let text):
            appState.homeInfo.insertHistoryKeyword(text: text)
        case .clearHistoryKeywords:
            appState.homeInfo.historyKeywords = nil
        case .updateSearchKeyword(let text):
            appState.homeInfo.searchKeyword = text
        case .updateViewControllersCount:
            appState.environment.viewControllersCount = viewControllersCount
        case .resetDownloadCommandResponse:
            appState.detailInfo.downloadCommandResponse = nil
            appState.detailInfo.downloadCommandSending = false
            appState.detailInfo.downloadCommandFailed = false
        case .replaceMangaCommentJumpID(let gid):
            appState.environment.mangaItemReverseID = gid
        case .updateIsSlideMenuClosed(let isClosed):
            appState.environment.isSlideMenuClosed = isClosed

        // MARK: App Env
        case .toggleAppUnlocked(let isUnlocked):
            appState.environment.isAppUnlocked = isUnlocked
        case .toggleBlurEffect(let effectOn):
            withAnimation(.linear(duration: 0.1)) {
                appState.environment.blurRadius = effectOn ? 10 : 0
            }
        case .toggleHomeListType(let type):
            appState.environment.homeListType = type
        case .toggleFavoriteIndex(let index):
            appState.environment.favoritesIndex = index
        case .toggleNavBarHidden(let isHidden):
            appState.environment.navBarHidden = isHidden
        case .toggleHomeViewSheetState(let state):
            if state != nil { impactFeedback(style: .light) }
            appState.environment.homeViewSheetState = state
        case .toggleSettingViewSheetState(let state):
            if state != nil { impactFeedback(style: .light) }
            appState.environment.settingViewSheetState = state
        case .toggleSettingViewActionSheetState(let state):
            appState.environment.settingViewActionSheetState = state
        case .toggleFilterViewActionSheetState(let state):
            appState.environment.filterViewActionSheetState = state
        case .toggleDetailViewSheetState(let state):
            if state != nil { impactFeedback(style: .light) }
            appState.environment.detailViewSheetState = state
        case .toggleCommentViewSheetState(let state):
            if state != nil { impactFeedback(style: .light) }
            appState.environment.commentViewSheetState = state

        case .clearDetailViewCommentContent:
            appState.detailInfo.commentContent = ""
        case .clearCommentViewCommentContent:
            appState.commentInfo.commentContent = ""

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
                print(error)
            }

        case .fetchUserInfo:
            guard let uid = appState.settings.user?.apiuid, !uid.isEmpty,
                    !appState.settings.userInfoLoading
            else { break }
            appState.settings.userInfoLoading = true

            appCommand = FetchUserInfoCommand(uid: uid)
        case .fetchUserInfoDone(let result):
            appState.settings.userInfoLoading = false

            switch result {
            case .success(let user):
                appState.settings.update(user: user)
            case .failure(let error):
                print(error)
            }

        case .fetchFavoriteNames:
            if appState.settings.favoriteNamesLoading { break }
            appState.settings.favoriteNamesLoading = true

            appCommand = FetchFavoriteNamesCommand()
        case .fetchFavoriteNamesDone(let result):
            appState.settings.favoriteNamesLoading = false

            switch result {
            case .success(let names):
                appState.settings.user?.favoriteNames = names
            case .failure(let error):
                print(error)
            }

        case .fetchMangaItemReverse(let detailURL):
            appState.environment.mangaItemReverseLoadFailed = false

            if appState.environment.mangaItemReverseLoading { break }
            appState.environment.mangaItemReverseLoading = true

            appCommand = FetchMangaItemReverseCommand(detailURL: detailURL)
        case .fetchMangaItemReverseDone(let result):
            appState.environment.mangaItemReverseLoading = false

            switch result {
            case .success(let manga):
                appState.cachedList.cache(mangas: [manga])
                appState.environment.mangaItemReverseID = manga.gid
            case .failure(let error):
                appState.environment.mangaItemReverseLoadFailed = true
                print(error)
            }

        case .fetchSearchItems(let keyword):
            appState.homeInfo.searchNotFound = false
            appState.homeInfo.searchLoadFailed = false

            if appState.homeInfo.searchLoading { break }
            appState.homeInfo.searchCurrentPageNum = 0
            appState.homeInfo.searchLoading = true

            let filter = appState.settings.filter ?? Filter()
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
                    appState.cachedList.cache(mangas: mangas.2)
                }
            case .failure(let error):
                appState.homeInfo.searchLoadFailed = true
                print(error)
            }

        case .fetchMoreSearchItems(let keyword):
            appState.homeInfo.moreSearchLoadFailed = false

            let currentNum = appState.homeInfo.searchCurrentPageNum
            let maximumNum = appState.homeInfo.searchPageNumMaximum
            if currentNum + 1 > maximumNum { break }

            if appState.homeInfo.moreSearchLoading { break }
            appState.homeInfo.moreSearchLoading = true

            let filter = appState.settings.filter ?? Filter()
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
                appState.cachedList.cache(mangas: mangas.2)

                if mangas.1.current < mangas.1.maximum && mangas.2.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.dispatch(.fetchMoreSearchItems(keyword: mangas.0))
                    }
                } else if appState.homeInfo.searchItems?.isEmpty == true {
                    appState.homeInfo.searchNotFound = true
                }
            case .failure(let error):
                appState.homeInfo.moreSearchLoadFailed = true
                print(error)
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
                    appState.cachedList.cache(mangas: mangas.1)
                }
            case .failure(let error):
                appState.homeInfo.frontpageLoadFailed = true
                print(error)
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
                appState.cachedList.cache(mangas: mangas.1)

                if mangas.0.current < mangas.0.maximum && mangas.1.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.dispatch(.fetchMoreFrontpageItems)
                    }
                } else if appState.homeInfo.frontpageItems?.isEmpty == true {
                    appState.homeInfo.frontpageNotFound = true
                }
            case .failure(let error):
                appState.homeInfo.moreFrontpageLoadFailed = true
                print(error)
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
                    appState.cachedList.cache(mangas: mangas.1)
                }
            case .failure(let error):
                print(error)
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
                    appState.cachedList.cache(mangas: mangas.1)
                }
            case .failure(let error):
                print(error)
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
                appState.cachedList.cache(mangas: mangas.1)

                if mangas.0.current < mangas.0.maximum && mangas.1.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.dispatch(.fetchMoreWatchedItems)
                    }
                } else if appState.homeInfo.watchedItems?.isEmpty == true {
                    appState.homeInfo.watchedNotFound = true
                }
            case .failure(let error):
                appState.homeInfo.moreWatchedLoadFailed = true
                print(error)
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
                    appState.cachedList.cache(mangas: mangas.1)
                }
            case .failure(let error):
                appState.homeInfo.favoritesLoadFailed[carriedValue] = true
                print(error)
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
                appState.cachedList.cache(mangas: mangas.1)

                if mangas.0.current < mangas.0.maximum && mangas.1.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.dispatch(.fetchMoreFavoritesItems(index: carriedValue))
                    }
                } else if appState.homeInfo.favoritesItems[carriedValue]?.isEmpty == true {
                    appState.homeInfo.favoritesNotFound[carriedValue] = true
                }
            case .failure(let error):
                appState.homeInfo.moreFavoritesLoading[carriedValue] = true
                print(error)
            }

        case .fetchMangaDetail(let gid):
            appState.detailInfo.mangaDetailLoadFailed = false

            if appState.detailInfo.mangaDetailLoading { break }
            appState.detailInfo.mangaDetailLoading = true

            let detailURL = appState.cachedList.items?[gid]?.detailURL ?? ""
            appCommand = FetchMangaDetailCommand(gid: gid, detailURL: detailURL)
        case .fetchMangaDetailDone(let result):
            appState.detailInfo.mangaDetailLoading = false

            switch result {
            case .success(let detail):
                appState.settings.user?.apikey = detail.2
                appState.cachedList.insertDetail(gid: detail.0, detail: detail.1)
            case .failure(let error):
                print(error)
                appState.detailInfo.mangaDetailLoadFailed = true
            }

        case .fetchMangaArchive(let gid):
            appState.detailInfo.mangaArchiveLoadFailed = false

            if appState.detailInfo.mangaArchiveLoading { break }
            appState.detailInfo.mangaArchiveLoading = true

            let archiveURL = appState.cachedList.items?[gid]?.detail?.archiveURL ?? ""
            appCommand = FetchMangaArchiveCommand(gid: gid, archiveURL: archiveURL)
        case .fetchMangaArchiveDone(let result):
            appState.detailInfo.mangaArchiveLoading = false

            switch result {
            case .success(let archive):
                appState.cachedList.insertArchive(gid: archive.0, archive: archive.1)

                if let currentGP = archive.2,
                   let currentCredits = archive.3
                {
                    appState.settings.update(
                        user: User(
                            currentGP: currentGP,
                            currentCredits: currentCredits
                        )
                    )
                }
            case .failure(let error):
                print(error)
                appState.detailInfo.mangaArchiveLoadFailed = true
            }

        case .fetchMangaArchiveFunds(let gid):
            if appState.detailInfo.mangaArchiveFundsLoading { break }
            appState.detailInfo.mangaArchiveFundsLoading = true

            let detailURL = appState.cachedList.items?[gid]?.detailURL ?? ""
            appCommand = FetchMangaArchiveFundsCommand(detailURL: detailURL)
        case .fetchMangaArchiveFundsDone(let result):
            appState.detailInfo.mangaArchiveFundsLoading = false

            switch result {
            case .success(let funds):
                appState.settings.update(
                    user: User(
                        currentGP: funds.0,
                        currentCredits: funds.1
                    )
                )
            case .failure(let error):
                print(error)
            }

        case .fetchMangaTorrents(let gid):
            appState.detailInfo.mangaTorrentsLoadFailed = false

            if appState.detailInfo.mangaTorrentsLoading { break }
            appState.detailInfo.mangaTorrentsLoading = true

            let token = appState.cachedList.items?[gid]?.token ?? ""
            appCommand = FetchMangaTorrentsCommand(gid: gid, token: token)
        case .fetchMangaTorrentsDone(let result):
            appState.detailInfo.mangaTorrentsLoading = false

            switch result {
            case .success(let torrents):
                appState.cachedList.insertTorrents(gid: torrents.0, torrents: torrents.1)
            case .failure(let error):
                print(error)
                appState.detailInfo.mangaTorrentsLoadFailed = true
            }

        case .fetchAssociatedItems(let depth, let keyword):
            appState.detailInfo.associatedItemsNotFound = false
            appState.detailInfo.associatedItemsLoadFailed = false

            if appState.detailInfo.associatedItemsLoading { break }
            appState.detailInfo.removeAssociatedItems(depth: depth)
            appState.detailInfo.associatedItemsLoading = true

            appCommand = FetchAssociatedItemsCommand(depth: depth, keyword: keyword)
        case .fetchAssociatedItemsDone(let result):
            appState.detailInfo.associatedItemsLoading = false

            switch result {
            case .success(let mangas):
                appState.detailInfo.replaceAssociatedItems(
                    depth: mangas.0,
                    keyword: mangas.1,
                    pageNum: mangas.2,
                    items: mangas.3
                )
                if mangas.3.isEmpty {
                    if mangas.2.current < mangas.2.maximum {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            self?.dispatch(.fetchMoreAssociatedItems(depth: mangas.0, keyword: mangas.1))
                        }
                    } else {
                        appState.detailInfo.associatedItemsNotFound = true
                    }
                } else {
                    appState.cachedList.cache(mangas: mangas.3)
                }
            case .failure(let error):
                print(error)
                appState.detailInfo.associatedItemsLoadFailed = true
            }

        case .fetchMoreAssociatedItems(let depth, let keyword):
            appState.detailInfo.moreAssociatedItemsLoadFailed = false

            guard appState.detailInfo.associatedItems.count >= depth + 1 else { break }
            let currentNum = appState.detailInfo.associatedItems[depth].pageNum.current
            let maximumNum = appState.detailInfo.associatedItems[depth].pageNum.maximum
            if currentNum + 1 > maximumNum { break }

            if appState.detailInfo.moreAssociatedItemsLoading { break }
            appState.detailInfo.moreAssociatedItemsLoading = true

            let lastID = appState.detailInfo.associatedItems[depth].mangas.last?.id ?? ""
            let pageNum = currentNum + 1
            appCommand = FetchMoreAssociatedItemsCommand(
                depth: depth,
                keyword: keyword,
                lastID: lastID,
                pageNum: pageNum
            )
        case .fetchMoreAssociatedItemsDone(let result):
            appState.detailInfo.moreAssociatedItemsLoading = false

            switch result {
            case .success(let mangas):
                appState.detailInfo.insertAssociatedItems(
                    depth: mangas.0,
                    keyword: mangas.1,
                    pageNum: mangas.2,
                    items: mangas.3
                )
                appState.cachedList.cache(mangas: mangas.3)

                if mangas.2.current < mangas.2.maximum && mangas.3.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.dispatch(.fetchMoreAssociatedItems(depth: mangas.0, keyword: mangas.1))
                    }
                } else if appState.detailInfo.associatedItems.isEmpty {
                    appState.detailInfo.associatedItemsNotFound = true
                }
            case .failure(let error):
                appState.detailInfo.moreAssociatedItemsLoadFailed = true
                print(error)
            }

        case .fetchAlterImages(let gid):
            if appState.detailInfo.alterImagesLoading { break }
            appState.detailInfo.alterImagesLoading = true

            let alterImagesURL = appState.cachedList.items?[gid]?.detail?.alterImagesURL ?? ""
            appCommand = FetchAlterImagesCommand(gid: gid, alterImagesURL: alterImagesURL)

        case .fetchAlterImagesDone(let result):
            appState.detailInfo.alterImagesLoading = false

            switch result {
            case .success(let images):
                appState.cachedList.insertAlterImages(gid: images.0, images: images.1)
            case .failure(let error):
                print(error)
            }

        case .updateMangaDetail(let gid):
            if appState.detailInfo.mangaDetailUpdating { break }
            appState.detailInfo.mangaDetailUpdating = true

            let detailURL = appState.cachedList.items?[gid]?.detailURL ?? ""
            appCommand = UpdateMangaDetailCommand(gid: gid, detailURL: detailURL)
        case .updateMangaDetailDone(let result):
            appState.detailInfo.mangaDetailUpdating = false

            switch result {
            case .success(let detail):
                appState.cachedList.updateDetail(gid: detail.0, detail: detail.1)
            case .failure(let error):
                print(error)
            }

        case .updateMangaComments(let gid):
            if appState.detailInfo.mangaCommentsUpdating { break }
            appState.detailInfo.mangaCommentsUpdating = true

            let detailURL = appState.cachedList.items?[gid]?.detailURL ?? ""
            appCommand = UpdateMangaCommentsCommand(gid: gid, detailURL: detailURL)
        case .updateMangaCommentsDone(result: let result):
            appState.detailInfo.mangaCommentsUpdating = false

            switch result {
            case .success(let comments):
                appState.cachedList.updateComments(gid: comments.0, comments: comments.1)
            case .failure(let error):
                print(error)
            }

        case .fetchMangaContents(let gid):
            appState.contentInfo.mangaContentsLoadFailed = false

            if appState.contentInfo.mangaContentsLoading { break }
            appState.contentInfo.mangaContentsLoading = true

            appState.cachedList.items?[gid]?.detail?.currentPageNum = 0

            let detailURL = appState.cachedList.items?[gid]?.detailURL ?? ""
            appCommand = FetchMangaContentsCommand(gid: gid, detailURL: detailURL)
        case .fetchMangaContentsDone(let result):
            appState.contentInfo.mangaContentsLoading = false

            switch result {
            case .success(let contents):
                appState.cachedList.insertContents(
                    gid: contents.0,
                    pageNum: contents.1,
                    contents: contents.2
                )
            case .failure(let error):
                appState.contentInfo.mangaContentsLoadFailed = true
                print(error)
            }

        case .fetchMoreMangaContents(let gid):
            appState.contentInfo.moreMangaContentsLoadFailed = false

            guard let manga = appState.cachedList.items?[gid],
                  let detail = manga.detail
            else { break }

            let currentNum = detail.currentPageNum
            let maximumNum = detail.pageNumMaximum
            if currentNum + 1 >= maximumNum { break }

            if appState.contentInfo.moreMangaContentsLoading { break }
            appState.contentInfo.moreMangaContentsLoading = true

            let detailURL = manga.detailURL
            let pageNum = currentNum + 1
            let pageCount = manga.contents?.count ?? 0
            appCommand = FetchMoreMangaContentsCommand(
                gid: gid,
                detailURL: detailURL,
                pageNum: pageNum,
                pageCount: pageCount
            )
        case .fetchMoreMangaContentsDone(let result):
            appState.contentInfo.moreMangaContentsLoading = false

            switch result {
            case .success(let contents):
                appState.cachedList.insertContents(
                    gid: contents.0,
                    pageNum: contents.1,
                    contents: contents.2
                )
            case .failure(let error):
                appState.contentInfo.moreMangaContentsLoadFailed = true
                print(error)
            }

        // MARK: Account Ops
        case .addFavorite(let gid, let favIndex):
            let token = appState.cachedList.items?[gid]?.token ?? ""
            appCommand = AddFavoriteCommand(gid: gid, token: token, favIndex: favIndex)
        case .deleteFavorite(let gid):
            appCommand = DeleteFavoriteCommand(gid: gid)

        case .sendDownloadCommand(let gid, let resolution):
            appState.detailInfo.downloadCommandFailed = false

            if appState.detailInfo.downloadCommandSending { break }
            appState.detailInfo.downloadCommandSending = true

            let archiveURL = appState.cachedList.items?[gid]?.detail?.archiveURL ?? ""
            appCommand = SendDownloadCommand(gid: gid, archiveURL: archiveURL, resolution: resolution)
        case .sendDownloadCommandDone(let result):
            appState.detailInfo.downloadCommandSending = false

            switch result {
            case Defaults.Response.hathClientNotFound,
                 Defaults.Response.hathClientNotOnline,
                 Defaults.Response.invalidResolution,
                 .none:
                appState.detailInfo.downloadCommandFailed = true
            default:
                break
            }

            appState.detailInfo.downloadCommandResponse = result

        case .rate(let gid, let rating):
            guard let apiuidString = appState.settings.user?.apiuid,
                  let apikey = appState.settings.user?.apikey,
                  let token = appState.cachedList.items?[gid]?.token,
                  let apiuid = Int(apiuidString),
                  let gid = Int(gid)
            else { break }

            appState.cachedList.updateUserRating(
                gid: String(gid), rating: Float(rating) / 2.0
            )

            appCommand = RateCommand(
                apiuid: apiuid,
                apikey: apikey,
                gid: gid,
                token: token,
                rating: rating
            )

        case .comment(let gid, let content):
            let detailURL = appState.cachedList.items?[gid]?.detailURL ?? ""
            appCommand = CommentCommand(gid: gid, content: content, detailURL: detailURL)
        case .editComment(let gid, let commentID, let content):
            let detailURL = appState.cachedList.items?[gid]?.detailURL ?? ""

            appCommand = EditCommentCommand(
                gid: gid,
                commentID: commentID,
                content: content,
                detailURL: detailURL
            )
        case .voteComment(let gid, let commentID, let vote):
            guard let apiuidString = appState.settings.user?.apiuid,
                  let apikey = appState.settings.user?.apikey,
                  let token = appState.cachedList.items?[gid]?.token,
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
