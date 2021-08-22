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
    static var preview: Store = {
        let store = Store()
        store.appState.environment.isPreview = true
        return store
    }()

    func dispatch(_ action: AppAction) {
        #if DEBUG
        guard !appState.environment.isPreview,
              !isUnitTesting
        else { return }
        #endif

        if Thread.isMainThread {
            privateDispatch(action)
        } else {
            DispatchQueue.main.async { [weak self] in
                self?.privateDispatch(action)
            }
        }
    }

    private func privateDispatch(_ action: AppAction) {
        let description = String(describing: action)
        if description.contains("error") {
            SwiftyBeaver.error("[ACTION]: " + description)
        } else {
            switch action {
            case .fetchGalleryPreviewsDone(let gid, let pageNumber, let result):
                if case .success(let previews) = result {
                    SwiftyBeaver.verbose(
                        "[ACTION]: fetchGalleryPreviewsDone("
                        + "gid: \(gid), "
                        + "pageNumber: \(pageNumber), "
                        + "previews: \(previews.count))"
                    )
                }
            case .fetchGalleryContentsDone(let gid, let pageNumber, let result):
                if case .success(let contents) = result {
                    SwiftyBeaver.verbose(
                        "[ACTION]: fetchGalleryContentsDone("
                        + "gid: \(gid), "
                        + "pageNumber: \(pageNumber), "
                        + "contents: \(contents.count))"
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
        case .updateSetting(let setting):
            appState.settings.setting = setting
        case .updateViewControllersCount:
            appState.environment.viewControllersCount = viewControllersCount
        case .replaceGalleryCommentJumpID(let gid):
            appState.environment.galleryItemReverseID = gid
        case .updateIsSlideMenuClosed(let isClosed):
            appState.environment.isSlideMenuClosed = isClosed
        case .fulfillGalleryPreviews(let gid):
            appState.detailInfo.fulfillPreviews(gid: gid)
        case .fulfillGalleryContents(let gid):
            appState.contentInfo.fulfillContents(gid: gid)

        // MARK: App Env
        case .toggleApp(let unlocked):
            appState.environment.isAppUnlocked = unlocked
        case .toggleBlur(let effectOn):
            withAnimation(.linear(duration: 0.1)) {
                appState.environment.blurRadius = effectOn ? 10 : 0
            }
        case .toggleHomeList(let type):
            appState.environment.homeListType = type
        case .toggleFavorites(let index):
            appState.environment.favoritesIndex = index
        case .toggleToplists(let type):
            appState.environment.toplistsType = type
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
        case .fetchIgneous:
            appCommand = FetchIgneousCommand()
        case .fetchTagTranslator:
            guard let preferredLanguage = Locale.preferredLanguages.first,
                  let language = TranslatableLanguage.allCases.compactMap({ lang in
                      preferredLanguage.contains(lang.languageCode) ? lang : nil
                  }).first
            else {
                appState.settings.tagTranslator = TagTranslator()
                appState.settings.setting.translatesTags = false
                break
            }
            if appState.settings.tagTranslator.language != language {
                appState.settings.tagTranslator = TagTranslator()
            }

            let updatedDate = appState.settings.tagTranslator.updatedDate
            appCommand = FetchTagTranslatorCommand(language: language, updatedDate: updatedDate)
        case .fetchTagTranslatorDone(let result):
            if case .success(let tagTranslator) = result {
                appState.settings.tagTranslator = tagTranslator
            }

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

        case .fetchGalleryItemReverse(var galleryURL):
            appState.environment.galleryItemReverseLoadFailed = false

            if appState.environment.galleryItemReverseLoading { break }
            appState.environment.galleryItemReverseLoading = true

            if appState.settings.setting.redirectsLinksToSelectedHost {
                galleryURL = galleryURL.replacingOccurrences(
                    of: Defaults.URL.ehentai,
                    with: Defaults.URL.host
                )
                .replacingOccurrences(
                    of: Defaults.URL.exhentai,
                    with: Defaults.URL.host
                )
            }
            appCommand = FetchGalleryItemReverseCommand(galleryURL: galleryURL)
        case .fetchGalleryItemReverseDone(let result):
            appState.environment.galleryItemReverseLoading = false

            switch result {
            case .success(let gallery):
                PersistenceController.add(galleries: [gallery])
                appState.environment.galleryItemReverseID = gallery.gid
            case .failure:
                appState.environment.galleryItemReverseLoadFailed = true
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
            case .success(let galleries):
                appState.homeInfo.searchCurrentPageNum = galleries.1.current
                appState.homeInfo.searchPageNumMaximum = galleries.1.maximum

                appState.homeInfo.searchItems = galleries.2
                if galleries.2.isEmpty {
                    if galleries.1.current < galleries.1.maximum {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            self?.dispatch(.fetchMoreSearchItems(keyword: galleries.0))
                        }
                    } else {
                        appState.homeInfo.searchNotFound = true
                    }
                } else {
                    PersistenceController.add(galleries: galleries.2)
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
            case .success(let galleries):
                appState.homeInfo.searchCurrentPageNum = galleries.1.current
                appState.homeInfo.searchPageNumMaximum = galleries.1.maximum

                appState.homeInfo.insertSearchItems(galleries: galleries.2)
                PersistenceController.add(galleries: galleries.2)

                if galleries.1.current < galleries.1.maximum && galleries.2.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.dispatch(.fetchMoreSearchItems(keyword: galleries.0))
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
            case .success(let galleries):
                appState.homeInfo.frontpageCurrentPageNum = galleries.0.current
                appState.homeInfo.frontpagePageNumMaximum = galleries.0.maximum

                appState.homeInfo.frontpageItems = galleries.1
                if galleries.1.isEmpty {
                    if galleries.0.current < galleries.0.maximum {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            self?.dispatch(.fetchMoreFrontpageItems)
                        }
                    } else {
                        appState.homeInfo.frontpageNotFound = true
                    }
                } else {
                    PersistenceController.add(galleries: galleries.1)
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
            case .success(let galleries):
                appState.homeInfo.frontpageCurrentPageNum = galleries.0.current
                appState.homeInfo.frontpagePageNumMaximum = galleries.0.maximum

                appState.homeInfo.insertFrontpageItems(galleries: galleries.1)
                PersistenceController.add(galleries: galleries.1)

                if galleries.0.current < galleries.0.maximum && galleries.1.isEmpty {
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
            case .success(let galleries):
                if galleries.1.isEmpty {
                    appState.homeInfo.popularNotFound = true
                } else {
                    appState.homeInfo.popularItems = galleries.1
                    PersistenceController.add(galleries: galleries.1)
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
            case .success(let galleries):
                appState.homeInfo.watchedCurrentPageNum = galleries.0.current
                appState.homeInfo.watchedPageNumMaximum = galleries.0.maximum

                appState.homeInfo.watchedItems = galleries.1
                if galleries.1.isEmpty {
                    if galleries.0.current < galleries.0.maximum {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            self?.dispatch(.fetchMoreWatchedItems)
                        }
                    } else {
                        appState.homeInfo.watchedNotFound = true
                    }
                } else {
                    PersistenceController.add(galleries: galleries.1)
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
            case .success(let galleries):
                appState.homeInfo.watchedCurrentPageNum = galleries.0.current
                appState.homeInfo.watchedPageNumMaximum = galleries.0.maximum

                appState.homeInfo.insertWatchedItems(galleries: galleries.1)
                PersistenceController.add(galleries: galleries.1)

                if galleries.0.current < galleries.0.maximum && galleries.1.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.dispatch(.fetchMoreWatchedItems)
                    }
                } else if appState.homeInfo.watchedItems?.isEmpty == true {
                    appState.homeInfo.watchedNotFound = true
                }
            case .failure:
                appState.homeInfo.moreWatchedLoadFailed = true
            }

        case .fetchFavoritesItems:
            let favIndex = appState.environment.favoritesIndex
            appState.homeInfo.favoritesNotFound[favIndex] = false
            appState.homeInfo.favoritesLoadFailed[favIndex] = false

            if appState.homeInfo.favoritesLoading[favIndex] != false { break }
            appState.homeInfo.favoritesCurrentPageNum[favIndex] = 0
            appState.homeInfo.favoritesLoading[favIndex] = true
            appCommand = FetchFavoritesItemsCommand(favIndex: favIndex)
        case .fetchFavoritesItemsDone(let carriedValue, let result):
            appState.homeInfo.favoritesLoading[carriedValue] = false

            switch result {
            case .success(let galleries):
                appState.homeInfo.favoritesCurrentPageNum[carriedValue] = galleries.0.current
                appState.homeInfo.favoritesPageNumMaximum[carriedValue] = galleries.0.maximum

                appState.homeInfo.favoritesItems[carriedValue] = galleries.1
                if galleries.1.isEmpty {
                    if galleries.0.current < galleries.0.maximum {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            self?.dispatch(.fetchMoreFavoritesItems)
                        }
                    } else {
                        appState.homeInfo.favoritesNotFound[carriedValue] = true
                    }
                } else {
                    PersistenceController.add(galleries: galleries.1)
                }
            case .failure:
                appState.homeInfo.favoritesLoadFailed[carriedValue] = true
            }

        case .fetchMoreFavoritesItems:
            let favIndex = appState.environment.favoritesIndex
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
            case .success(let galleries):
                appState.homeInfo.favoritesCurrentPageNum[carriedValue] = galleries.0.current
                appState.homeInfo.favoritesPageNumMaximum[carriedValue] = galleries.0.maximum

                appState.homeInfo.insertFavoritesItems(favIndex: carriedValue, galleries: galleries.1)
                PersistenceController.add(galleries: galleries.1)

                if galleries.0.current < galleries.0.maximum && galleries.1.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.dispatch(.fetchMoreFavoritesItems)
                    }
                } else if appState.homeInfo.favoritesItems[carriedValue]?.isEmpty == true {
                    appState.homeInfo.favoritesNotFound[carriedValue] = true
                }
            case .failure:
                appState.homeInfo.moreFavoritesLoading[carriedValue] = true
            }

        case .fetchToplistsItems:
            let topType = appState.environment.toplistsType
            appState.homeInfo.toplistsNotFound[topType.rawValue] = false
            appState.homeInfo.toplistsLoadFailed[topType.rawValue] = false

            if appState.homeInfo.toplistsLoading[topType.rawValue] != false { break }
            appState.homeInfo.toplistsCurrentPageNum[topType.rawValue] = 0
            appState.homeInfo.toplistsLoading[topType.rawValue] = true
            appCommand = FetchToplistsItemsCommand(
                topIndex: topType.rawValue, catIndex: topType.categoryIndex
            )
        case .fetchToplistsItemsDone(let carriedValue, let result):
            appState.homeInfo.toplistsLoading[carriedValue] = false

            switch result {
            case .success(let galleries):
                appState.homeInfo.toplistsCurrentPageNum[carriedValue] = galleries.0.current
                appState.homeInfo.toplistsPageNumMaximum[carriedValue] = galleries.0.maximum

                appState.homeInfo.toplistsItems[carriedValue] = galleries.1
                if galleries.1.isEmpty {
                    if galleries.0.current < galleries.0.maximum {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                            self?.dispatch(.fetchMoreToplistsItems)
                        }
                    } else {
                        appState.homeInfo.toplistsNotFound[carriedValue] = true
                    }
                } else {
                    PersistenceController.add(galleries: galleries.1)
                }
            case .failure:
                appState.homeInfo.toplistsLoadFailed[carriedValue] = true
            }

        case .fetchMoreToplistsItems:
            let topType = appState.environment.toplistsType
            appState.homeInfo.moreToplistsLoadFailed[topType.rawValue] = false

            let currentNum = appState.homeInfo.toplistsCurrentPageNum[topType.rawValue]
            let maximumNum = appState.homeInfo.toplistsPageNumMaximum[topType.rawValue]
            if (currentNum ?? 0) + 1 >= maximumNum ?? 1 { break }

            if appState.homeInfo.moreToplistsLoading[topType.rawValue] != false { break }
            appState.homeInfo.moreToplistsLoading[topType.rawValue] = true

            let pageNum = (appState.homeInfo.toplistsCurrentPageNum[topType.rawValue] ?? 0) + 1
            appCommand = FetchMoreToplistsItemsCommand(
                topIndex: topType.rawValue,
                catIndex: topType.categoryIndex,
                pageNum: pageNum
            )
        case .fetchMoreToplistsItemsDone(let carriedValue, let result):
            appState.homeInfo.moreToplistsLoading[carriedValue] = false

            switch result {
            case .success(let galleries):
                appState.homeInfo.toplistsCurrentPageNum[carriedValue] = galleries.0.current
                appState.homeInfo.toplistsPageNumMaximum[carriedValue] = galleries.0.maximum

                appState.homeInfo.insertToplistsItems(topIndex: carriedValue, galleries: galleries.1)
                PersistenceController.add(galleries: galleries.1)

                if galleries.0.current < galleries.0.maximum && galleries.1.isEmpty {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        self?.dispatch(.fetchMoreToplistsItems)
                    }
                } else if appState.homeInfo.toplistsItems[carriedValue]?.isEmpty == true {
                    appState.homeInfo.toplistsNotFound[carriedValue] = true
                }
            case .failure:
                appState.homeInfo.moreToplistsLoading[carriedValue] = true
            }

        case .fetchGalleryDetail(let gid):
            appState.detailInfo.detailLoadFailed[gid] = false

            if appState.detailInfo.detailLoading[gid] == true { break }
            appState.detailInfo.detailLoading[gid] = true

            let galleryURL = PersistenceController.fetchGallery(gid: gid)?.galleryURL ?? ""
            appCommand = FetchGalleryDetailCommand(gid: gid, galleryURL: galleryURL)
        case .fetchGalleryDetailDone(let gid, let result):
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
                appState.detailInfo.update(gid: gid, previews: detail.1.previews)
            case .failure:
                appState.detailInfo.detailLoadFailed[gid] = true
            }

        case .fetchGalleryArchiveFunds(let gid):
            if appState.detailInfo.archiveFundsLoading { break }
            appState.detailInfo.archiveFundsLoading = true
            let galleryURL = PersistenceController.fetchGallery(gid: gid)?.galleryURL ?? ""
            appCommand = FetchGalleryArchiveFundsCommand(gid: gid, galleryURL: galleryURL)
        case .fetchGalleryArchiveFundsDone(let result):
            appState.detailInfo.archiveFundsLoading = false

            if case .success(let funds) = result {
                appState.settings.update(
                    user: User(
                        currentGP: funds.0,
                        currentCredits: funds.1
                    )
                )
            }

        case .fetchGalleryPreviews(let gid, let index):
            let pageNumber = index / appState.detailInfo.previewConfig.batchSize
            if appState.detailInfo.previewsLoading[gid] == nil {
                appState.detailInfo.previewsLoading[gid] = [:]
            }

            if appState.detailInfo.previewsLoading[gid]?[pageNumber] == true { break }
            appState.detailInfo.previewsLoading[gid]?[pageNumber] = true

            let galleryURL = PersistenceController.fetchGallery(gid: gid)?.galleryURL ?? ""
            let url = Defaults.URL.detailPage(url: galleryURL, pageNum: pageNumber)
            appCommand = FetchGalleryPreviewsCommand(gid: gid, url: url, pageNumber: pageNumber)

        case .fetchGalleryPreviewsDone(let gid, let pageNumber, let result):
            appState.detailInfo.previewsLoading[gid]?[pageNumber] = false

            switch result {
            case .success(let previews):
                appState.detailInfo.update(gid: gid, previews: previews)
                PersistenceController.update(fetchedState: GalleryState(gid: gid, previews: previews))
            case .failure(let error):
                SwiftyBeaver.error(error)
            }

        case .fetchGalleryContents(let gid, let index):
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

            let galleryURL = PersistenceController.fetchGallery(gid: gid)?.galleryURL ?? ""
            let url = Defaults.URL.detailPage(url: galleryURL, pageNum: pageNumber)
            appCommand = FetchGalleryContentsCommand(gid: gid, url: url, pageNumber: pageNumber)
        case .fetchGalleryContentsDone(let gid, let pageNumber, let result):
            appState.contentInfo.contentsLoading[gid]?[pageNumber] = false

            switch result {
            case .success(let contents):
                appState.contentInfo.update(gid: gid, contents: contents)
                PersistenceController.update(gid: gid, contents: contents)
            case .failure(let error):
                if case .mpvActivated(let mpvKey, let imgKeys) = error {
                    appState.contentInfo.mpvKeys[gid] = mpvKey
                    appState.contentInfo.mpvImageKeys[gid] = imgKeys
                } else {
                    appState.contentInfo.contentsLoadFailed[gid]?[pageNumber] = true
                }
            }

        case .fetchGalleryMPVContent(let gid, let index):
            guard let gidInteger = Int(gid),
                  let mpvKey = appState.contentInfo.mpvKeys[gid],
                  let imgKey = appState.contentInfo.mpvImageKeys[gid]?[index]
            else { break }

            if appState.contentInfo.mpvImageLoading[gid] == nil {
                appState.contentInfo.mpvImageLoading[gid] = [:]
            }
            if appState.contentInfo.mpvImageLoading[gid]?[index] == true { break }
            appState.contentInfo.mpvImageLoading[gid]?[index] = true

            appCommand = FetchGalleryMPVContentCommand(
                gid: gidInteger, index: index, mpvKey: mpvKey, imgKey: imgKey
            )
        case .fetchGalleryMPVContentDone(let gid, let index, let result):
            appState.contentInfo.mpvImageLoading[gid]?[index] = false

            switch result {
            case .success(let imageURL):
                appState.contentInfo.update(gid: gid, contents: [index: imageURL])
                PersistenceController.update(gid: gid, contents: [index: imageURL])
            case .failure(let error):
                SwiftyBeaver.error(error)
            }

        // MARK: Account Ops
        case .createEhProfile(let name):
            appCommand = CreateEhProfileCommand(name: name)
        case .verifyEhProfile:
            appCommand = VerifyEhProfileCommand()
        case .verifyEhProfileDone(let result):
            switch result {
            case .success((let profileValue, let profileNotFound)):
                if let profileValue = profileValue {
                    let profileValueString = String(profileValue)
                    let hostURL = Defaults.URL.host.safeURL()
                    let selectedProfileKey =
                    Defaults.Cookie.selectedProfile

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
                    dispatch(.createEhProfile(name: "EhPanda"))
                } else {
                    SwiftyBeaver.error("Found profile but failed in parsing value.")
                }
            case .failure(let error):
                SwiftyBeaver.error(error)
            }
        case .addFavorite(let gid, let favIndex):
            let token = PersistenceController.fetchGallery(gid: gid)?.token ?? ""
            appCommand = AddFavoriteCommand(gid: gid, token: token, favIndex: favIndex)
        case .deleteFavorite(let gid):
            appCommand = DeleteFavoriteCommand(gid: gid)

        case .rate(let gid, let rating):
            let apiuidString = appState.settings.user.apiuid
            guard !apiuidString.isEmpty,
                  let apikey = appState.settings.user.apikey,
                  let token = PersistenceController.fetchGallery(gid: gid)?.token,
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
            let galleryURL = PersistenceController.fetchGallery(gid: gid)?.galleryURL ?? ""
            appCommand = CommentCommand(gid: gid, content: content, galleryURL: galleryURL)
        case .editComment(let gid, let commentID, let content):
            let galleryURL = PersistenceController.fetchGallery(gid: gid)?.galleryURL ?? ""

            appCommand = EditCommentCommand(
                gid: gid,
                commentID: commentID,
                content: content,
                galleryURL: galleryURL
            )
        case .voteComment(let gid, let commentID, let vote):
            let apiuidString = appState.settings.user.apiuid
            guard !apiuidString.isEmpty,
                  let apikey = appState.settings.user.apikey,
                  let token = PersistenceController.fetchGallery(gid: gid)?.token,
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
