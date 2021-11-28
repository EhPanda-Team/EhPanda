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
        guard !AppUtil.isUnitTesting else { return }
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
                        + "gid: \(gid), pageNumber: \(pageNumber), "
                        + "previews: \(previews.count))"
                    )
                }
            case .fetchThumbnailsDone(let gid, let index, let result):
                if case .success(let contents) = result {
                    SwiftyBeaver.verbose(
                        "[ACTION]: fetchThumbnailsDone("
                        + "gid: \(gid), index: \(index), "
                        + "contents: \(contents.count))"
                    )
                }
            case .fetchGalleryNormalContents(let gid, let index, let thumbnails):
                SwiftyBeaver.verbose(
                    "[ACTION]: fetchGalleryNormalContents("
                    + "gid: \(gid), index: \(index), "
                    + "thumbnails: \(thumbnails.count))"
                )
            case .fetchGalleryNormalContentsDone(let gid, let index, let result):
                if case .success(let contents) = result {
                    SwiftyBeaver.verbose(
                        "[ACTION]: fetchGalleryNormalContentsDone("
                        + "gid: \(gid), index: \(index), "
                        + "contents: \(contents.count))"
                    )
                }
            case .fetchMPVKeysDone(let gid, let index, let result):
                if case .success(let (mpvKey, imgKeys)) = result {
                    SwiftyBeaver.verbose(
                        "[ACTION]: fetchMPVKeysDone("
                        + "gid: \(gid), index: \(index), "
                        + "mpvKey: \(mpvKey), imgKeys: \(imgKeys.count))"
                    )
                }
            default:
                SwiftyBeaver.verbose("[ACTION]: " + description)
            }
        }
        let (state, command) = reduce(state: appState, action: action)
        appState = state

        guard let command = command else { return }
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
        case .resetHomeInfo:
            appState.homeInfo = AppState.HomeInfo()
            dispatch(.setHomeListType(.frontpage))
            dispatch(.fetchFrontpageItems(pageNum: nil))
        case .resetFilter(let range):
            switch range {
            case .search:
                appState.settings.searchFilter = Filter()
            case .global:
                appState.settings.globalFilter = Filter()
            }
        case .setReadingProgress(let gid, let tag):
            PersistenceController.update(gid: gid, readingProgress: tag)
        case .setAppIconType(let iconType):
            appState.settings.setting.appIconType = iconType
        case .appendHistoryKeywords(let texts):
            appState.homeInfo.appendHistoryKeywords(texts: texts)
        case .removeHistoryKeyword(let text):
            appState.homeInfo.removeHistoryKeyword(text: text)
        case .clearHistoryKeywords:
            appState.homeInfo.historyKeywords = []
        case .setSetting(let setting):
            appState.settings.setting = setting
        case .setViewControllersCount:
            appState.environment.viewControllersCount = DeviceUtil.viewControllersCount
        case .setGalleryCommentJumpID(let gid):
            appState.environment.galleryItemReverseID = gid
        case .setSlideMenuClosed(let closed):
            appState.environment.slideMenuClosed = closed
        case .fulfillGalleryPreviews(let gid):
            appState.detailInfo.fulfillPreviews(gid: gid)
        case .fulfillGalleryContents(let gid):
            appState.contentInfo.fulfillContents(gid: gid)
        case .setPendingJumpInfos(let gid, let pageIndex, let commentID):
            appState.detailInfo.pendingJumpPageIndices[gid] = pageIndex
            appState.detailInfo.pendingJumpCommentIDs[gid] = commentID
        case .appendQuickSearchWord:
            appState.homeInfo.appendQuickSearchWord()
        case .deleteQuickSearchWord(let offsets):
            appState.homeInfo.deleteQuickSearchWords(offsets: offsets)
        case .modifyQuickSearchWord(let newWord):
            appState.homeInfo.modifyQuickSearchWord(newWord: newWord)
        case .moveQuickSearchWord(let source, let destination):
            appState.homeInfo.moveQuickSearchWords(source: source, destination: destination)

        // MARK: App Env
        case .setAppLock(let activated):
            appState.environment.isAppUnlocked = !activated
        case .setBlurEffect(let activated):
            withAnimation(.linear(duration: 0.1)) {
                appState.environment.blurRadius =
                    activated ? appState.settings.setting.backgroundBlurRadius : 0
            }
        case .setHomeListType(let type):
            appState.environment.homeListType = type
        case .setFavoritesIndex(let index):
            appState.environment.favoritesIndex = index
        case .setToplistsType(let type):
            appState.environment.toplistsType = type
        case .setNavigationBarHidden(let hidden):
            appState.environment.navigationBarHidden = hidden
        case .setHomeViewSheetState(let state):
            if state != nil { HapticUtil.generateFeedback(style: .light) }
            appState.environment.homeViewSheetState = state
        case .setSettingViewSheetState(let state):
            if state != nil { HapticUtil.generateFeedback(style: .light) }
            appState.environment.settingViewSheetState = state
        case .setDetailViewSheetState(let state):
            if state != nil { HapticUtil.generateFeedback(style: .light) }
            appState.environment.detailViewSheetState = state
        case .setCommentViewSheetState(let state):
            if state != nil { HapticUtil.generateFeedback(style: .light) }
            appState.environment.commentViewSheetState = state

        // MARK: Fetch Data
        case .handleJumpPage(let index, let keyword):
            DispatchQueue.main.async { [weak self] in
                switch appState.environment.homeListType {
                case .search:
                    guard let keyword = keyword else { break }
                    self?.dispatch(.fetchSearchItems(keyword: keyword, pageNum: index))
                case .frontpage:
                    self?.dispatch(.fetchFrontpageItems(pageNum: index))
                case .watched:
                    self?.dispatch(.fetchWatchedItems(pageNum: index))
                case .favorites:
                    self?.dispatch(.fetchFavoritesItems(pageNum: index))
                case .toplists:
                    self?.dispatch(.fetchToplistsItems(pageNum: index))
                case .popular, .downloaded, .history:
                    break
                }
            }
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

        case .fetchGalleryItemReverse(var url, let shouldParseGalleryURL):
            appState.environment.galleryItemReverseLoadFailed = false

            guard let tmpURL = URL(string: url),
                  tmpURL.pathComponents.count >= 4 else { break }
            if appState.environment.galleryItemReverseLoading { break }
            appState.environment.galleryItemReverseLoading = true

            if appState.settings.setting.redirectsLinksToSelectedHost {
                url = url.replacingOccurrences(
                    of: Defaults.URL.ehentai,
                    with: Defaults.URL.host
                )
                .replacingOccurrences(
                    of: Defaults.URL.exhentai,
                    with: Defaults.URL.host
                )
            }
            appCommand = FetchGalleryItemReverseCommand(
                gid: URLUtil.parseGID(url: tmpURL, isGalleryURL: shouldParseGalleryURL),
                url: url, shouldParseGalleryURL: shouldParseGalleryURL
            )
        case .fetchGalleryItemReverseDone(let carriedValue, let result):
            appState.environment.galleryItemReverseLoading = false

            switch result {
            case .success(let gallery):
                PersistenceController.add(galleries: [gallery])
                appState.environment.galleryItemReverseID = gallery.gid
            case .failure:
                appState.environment.galleryItemReverseLoadFailed = true
                dispatch(.setPendingJumpInfos(gid: carriedValue, pageIndex: nil, commentID: nil))
            }

        case .fetchSearchItems(let keyword, let pageNum):
            appState.homeInfo.searchLoadError = nil

            if appState.homeInfo.searchLoading { break }
            appState.homeInfo.searchPageNumber.current = 0
            appState.homeInfo.searchLoading = true

            let filter = appState.settings.searchFilter
            appCommand = FetchSearchItemsCommand(keyword: keyword, filter: filter, pageNum: pageNum)
        case .fetchSearchItemsDone(let result):
            appState.homeInfo.searchLoading = false

            switch result {
            case .success(let (pageNumber, galleries)):
                appState.homeInfo.searchItems = galleries
                PersistenceController.add(galleries: galleries)
                appState.homeInfo.searchPageNumber = pageNumber
            case .failure(let error):
                appState.homeInfo.searchLoadError = error
            }

        case .fetchMoreSearchItems(let keyword):
            appState.homeInfo.moreSearchLoadFailed = false

            let pageNumber = appState.homeInfo.searchPageNumber
            if pageNumber.current + 1 > pageNumber.maximum { break }

            if appState.homeInfo.moreSearchLoading { break }
            appState.homeInfo.moreSearchLoading = true

            let pageNum = pageNumber.current + 1
            let filter = appState.settings.searchFilter
            let lastID = appState.homeInfo.searchItems.last?.id ?? ""
            appCommand = FetchMoreSearchItemsCommand(
                keyword: keyword, filter: filter,
                lastID: lastID, pageNum: pageNum
            )
        case .fetchMoreSearchItemsDone(let result):
            appState.homeInfo.moreSearchLoading = false

            switch result {
            case .success(let (pageNumber, galleries)):
                appState.homeInfo.searchPageNumber = pageNumber
                appState.homeInfo.insertSearchItems(galleries: galleries)
                PersistenceController.add(galleries: galleries)
            case .failure:
                appState.homeInfo.moreSearchLoadFailed = true
            }

        case .fetchFrontpageItems(let pageNum):
            appState.homeInfo.frontpageLoadError = nil

            if appState.homeInfo.frontpageLoading { break }
            appState.homeInfo.frontpagePageNumber.current = 0
            appState.homeInfo.frontpageLoading = true
            let filter = appState.settings.globalFilter
            appCommand = FetchFrontpageItemsCommand(filter: filter, pageNum: pageNum)
        case .fetchFrontpageItemsDone(let result):
            appState.homeInfo.frontpageLoading = false

            switch result {
            case .success(let (pageNumber, galleries)):
                appState.homeInfo.frontpagePageNumber = pageNumber
                appState.homeInfo.frontpageItems = galleries
                PersistenceController.add(galleries: galleries)
            case .failure(let error):
                appState.homeInfo.frontpageLoadError = error
            }

        case .fetchMoreFrontpageItems:
            appState.homeInfo.moreFrontpageLoadFailed = false

            let pageNumber = appState.homeInfo.frontpagePageNumber
            if pageNumber.current + 1 > pageNumber.maximum { break }

            if appState.homeInfo.moreFrontpageLoading { break }
            appState.homeInfo.moreFrontpageLoading = true

            let pageNum = pageNumber.current + 1
            let filter = appState.settings.globalFilter
            let lastID = appState.homeInfo.frontpageItems.last?.id ?? ""
            appCommand = FetchMoreFrontpageItemsCommand(filter: filter, lastID: lastID, pageNum: pageNum)
        case .fetchMoreFrontpageItemsDone(let result):
            appState.homeInfo.moreFrontpageLoading = false

            switch result {
            case .success(let (pageNumber, galleries)):
                appState.homeInfo.frontpagePageNumber = pageNumber
                appState.homeInfo.insertFrontpageItems(galleries: galleries)
                PersistenceController.add(galleries: galleries)
            case .failure:
                appState.homeInfo.moreFrontpageLoadFailed = true
            }

        case .fetchPopularItems:
            appState.homeInfo.popularLoadError = nil

            if appState.homeInfo.popularLoading { break }
            appState.homeInfo.popularLoading = true
            let filter = appState.settings.globalFilter
            appCommand = FetchPopularItemsCommand(filter: filter)
        case .fetchPopularItemsDone(let result):
            appState.homeInfo.popularLoading = false

            switch result {
            case .success(let galleries):
                appState.homeInfo.popularItems = galleries
                PersistenceController.add(galleries: galleries)
            case .failure(let error):
                appState.homeInfo.popularLoadError = error
            }

        case .fetchWatchedItems(let pageNum):
            appState.homeInfo.watchedLoadError = nil

            if appState.homeInfo.watchedLoading { break }
            appState.homeInfo.watchedPageNumber.current = 0
            appState.homeInfo.watchedLoading = true
            let filter = appState.settings.globalFilter
            appCommand = FetchWatchedItemsCommand(filter: filter, pageNum: pageNum)
        case .fetchWatchedItemsDone(let result):
            appState.homeInfo.watchedLoading = false

            switch result {
            case .success(let (pageNumber, galleries)):
                appState.homeInfo.watchedPageNumber = pageNumber
                appState.homeInfo.watchedItems = galleries
                PersistenceController.add(galleries: galleries)
            case .failure(let error):
                appState.homeInfo.watchedLoadError = error
            }

        case .fetchMoreWatchedItems:
            appState.homeInfo.moreWatchedLoadFailed = false

            let pageNumber = appState.homeInfo.watchedPageNumber
            if pageNumber.current + 1 > pageNumber.maximum { break }

            if appState.homeInfo.moreWatchedLoading { break }
            appState.homeInfo.moreWatchedLoading = true

            let pageNum = pageNumber.current + 1
            let filter = appState.settings.globalFilter
            let lastID = appState.homeInfo.watchedItems.last?.id ?? ""
            appCommand = FetchMoreWatchedItemsCommand(filter: filter, lastID: lastID, pageNum: pageNum)
        case .fetchMoreWatchedItemsDone(let result):
            appState.homeInfo.moreWatchedLoading = false

            switch result {
            case .success(let (pageNumber, galleries)):
                appState.homeInfo.watchedPageNumber = pageNumber
                appState.homeInfo.insertWatchedItems(galleries: galleries)
                PersistenceController.add(galleries: galleries)
            case .failure:
                appState.homeInfo.moreWatchedLoadFailed = true
            }

        case .fetchFavoritesItems(let pageNum, let sortOrder):
            let favIndex = appState.environment.favoritesIndex
            appState.homeInfo.favoritesLoadErrors[favIndex] = nil

            if appState.homeInfo.favoritesLoading[favIndex] == true { break }
            if appState.homeInfo.favoritesPageNumbers[favIndex] == nil {
                appState.homeInfo.favoritesPageNumbers[favIndex] = PageNumber()
            }
            appState.homeInfo.favoritesPageNumbers[favIndex]?.current = 0
            appState.homeInfo.favoritesLoading[favIndex] = true
            appCommand = FetchFavoritesItemsCommand(favIndex: favIndex, pageNum: pageNum, sortOrder: sortOrder)
        case .fetchFavoritesItemsDone(let carriedValue, let result):
            appState.homeInfo.favoritesLoading[carriedValue] = false

            switch result {
            case .success(let (pageNumber, sortOrder, galleries)):
                appState.homeInfo.favoritesPageNumbers[carriedValue] = pageNumber
                appState.homeInfo.favoritesItems[carriedValue] = galleries
                appState.environment.favoritesSortOrder = sortOrder
                PersistenceController.add(galleries: galleries)
            case .failure(let error):
                appState.homeInfo.favoritesLoadErrors[carriedValue] = error
            }

        case .fetchMoreFavoritesItems:
            let favIndex = appState.environment.favoritesIndex
            appState.homeInfo.moreFavoritesLoadFailed[favIndex] = false

            let pageNumber = appState.homeInfo.favoritesPageNumbers[favIndex]
            if (pageNumber?.current ?? 0) + 1 > pageNumber?.maximum ?? 0 { break }

            if appState.homeInfo.moreFavoritesLoading[favIndex] == true { break }
            appState.homeInfo.moreFavoritesLoading[favIndex] = true

            let pageNum = (pageNumber?.current ?? 0) + 1
            let lastID = appState.homeInfo.favoritesItems[favIndex]?.last?.id ?? ""
            appCommand = FetchMoreFavoritesItemsCommand(
                favIndex: favIndex, lastID: lastID, pageNum: pageNum
            )
        case .fetchMoreFavoritesItemsDone(let carriedValue, let result):
            appState.homeInfo.moreFavoritesLoading[carriedValue] = false

            switch result {
            case .success(let (pageNumber, sortOrder, galleries)):
                appState.homeInfo.favoritesPageNumbers[carriedValue] = pageNumber
                appState.homeInfo.insertFavoritesItems(favIndex: carriedValue, galleries: galleries)
                appState.environment.favoritesSortOrder = sortOrder
                PersistenceController.add(galleries: galleries)
            case .failure:
                appState.homeInfo.moreFavoritesLoading[carriedValue] = true
            }

        case .fetchToplistsItems(let pageNum):
            let topType = appState.environment.toplistsType
            appState.homeInfo.toplistsLoadErrors[topType.rawValue] = nil

            if appState.homeInfo.toplistsLoading[topType.rawValue] == true { break }
            if appState.homeInfo.toplistsPageNumbers[topType.rawValue] == nil {
                appState.homeInfo.toplistsPageNumbers[topType.rawValue] = PageNumber()
            }
            appState.homeInfo.toplistsPageNumbers[topType.rawValue]?.current = 0
            appState.homeInfo.toplistsLoading[topType.rawValue] = true
            appCommand = FetchToplistsItemsCommand(
                topIndex: topType.rawValue, catIndex: topType.categoryIndex, pageNum: pageNum
            )
        case .fetchToplistsItemsDone(let carriedValue, let result):
            appState.homeInfo.toplistsLoading[carriedValue] = false

            switch result {
            case .success(let (pageNumber, galleries)):
                appState.homeInfo.toplistsPageNumbers[carriedValue] = pageNumber
                appState.homeInfo.toplistsItems[carriedValue] = galleries
                PersistenceController.add(galleries: galleries)
            case .failure(let error):
                appState.homeInfo.toplistsLoadErrors[carriedValue] = error
            }

        case .fetchMoreToplistsItems:
            let topType = appState.environment.toplistsType
            appState.homeInfo.moreToplistsLoadFailed[topType.rawValue] = false

            let pageNumber = appState.homeInfo.toplistsPageNumbers[topType.rawValue]
            if (pageNumber?.current ?? 0) + 1 > pageNumber?.maximum ?? 0 { break }

            if appState.homeInfo.moreToplistsLoading[topType.rawValue] == true { break }
            appState.homeInfo.moreToplistsLoading[topType.rawValue] = true

            let pageNum = (pageNumber?.current ?? 0) + 1
            appCommand = FetchMoreToplistsItemsCommand(
                topIndex: topType.rawValue, catIndex: topType.categoryIndex, pageNum: pageNum
            )
        case .fetchMoreToplistsItemsDone(let carriedValue, let result):
            appState.homeInfo.moreToplistsLoading[carriedValue] = false

            switch result {
            case .success(let (pageNumber, galleries)):
                appState.homeInfo.toplistsPageNumbers[carriedValue] = pageNumber
                appState.homeInfo.insertToplistsItems(topIndex: carriedValue, galleries: galleries)
                PersistenceController.add(galleries: galleries)
            case .failure:
                appState.homeInfo.moreToplistsLoading[carriedValue] = true
            }

        case .fetchGalleryDetail(let gid):
            appState.detailInfo.detailLoadErrors[gid] = nil

            if appState.detailInfo.detailLoading[gid] == true { break }
            appState.detailInfo.detailLoading[gid] = true

            let galleryURL = PersistenceController.fetchGallery(gid: gid)?.galleryURL ?? ""
            appCommand = FetchGalleryDetailCommand(gid: gid, galleryURL: galleryURL)
        case .fetchGalleryDetailDone(let gid, let result):
            appState.detailInfo.detailLoading[gid] = false

            switch result {
            case .success(let (detail, state, apiKey, greeting)):
                appState.settings.user.apikey = apiKey
                if let greeting = greeting {
                    appState.settings.insert(greeting: greeting)
                }
                if let previewConfig = state.previewConfig {
                    appState.detailInfo.previewConfig = previewConfig
                }
                PersistenceController.add(detail: detail)
                PersistenceController.update(fetchedState: state)
                appState.detailInfo.update(gid: gid, previews: state.previews)
            case .failure(let error):
                appState.detailInfo.detailLoadErrors[gid] = error
            }

        case .fetchGalleryArchiveFunds(let gid):
            if appState.detailInfo.archiveFundsLoading { break }
            appState.detailInfo.archiveFundsLoading = true
            let galleryURL = PersistenceController.fetchGallery(gid: gid)?.galleryURL ?? ""
            appCommand = FetchGalleryArchiveFundsCommand(gid: gid, galleryURL: galleryURL)
        case .fetchGalleryArchiveFundsDone(let result):
            appState.detailInfo.archiveFundsLoading = false

            if case .success(let (currentGP, currentCredits)) = result {
                appState.settings.update(
                    user: User(
                        currentGP: currentGP,
                        currentCredits: currentCredits
                    )
                )
            }

        case .fetchGalleryPreviews(let gid, let index):
            let pageNumber = appState.detailInfo.previewConfig.pageNumber(index: index)
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

            if case .success(let previews) = result {
                appState.detailInfo.update(gid: gid, previews: previews)
                PersistenceController.update(fetchedState: GalleryState(gid: gid, previews: previews))
            }

        case .fetchMPVKeys(let gid, let index, let mpvURL):
            let pageCount = PersistenceController.fetchGallery(gid: gid)?.pageCount ?? -1
            appCommand = FetchMPVKeysCommand(gid: gid, mpvURL: mpvURL, pageCount: pageCount, index: index)
        case .fetchMPVKeysDone(let gid, let index, let result):
            let batchRange = appState.detailInfo.previewConfig.batchRange(index: index)
            batchRange.forEach { appState.contentInfo.contentsLoading[gid]?[$0] = false }

            switch result {
            case .success(let (mpvKey, imgKeys)):
                appState.contentInfo.mpvKeys[gid] = mpvKey
                appState.contentInfo.mpvImageKeys[gid] = imgKeys

                if appState.contentInfo.contents[gid]?.isEmpty == true,
                   let pageCount = PersistenceController.fetchGallery(gid: gid)?.pageCount {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                        Array(1...min(3, max(1, pageCount))).forEach { index in
                            self?.dispatch(.fetchGalleryMPVContent(gid: gid, index: index))
                        }
                    }
                }
            case .failure(let error):
                batchRange.forEach { appState.contentInfo.contentsLoadErrors[gid]?[$0] = error }
            }

        case .fetchThumbnails(let gid, let index):
            let batchRange = appState.detailInfo.previewConfig.batchRange(index: index)
            let pageNumber = appState.detailInfo.previewConfig.pageNumber(index: index)
            if appState.contentInfo.contentsLoading[gid] == nil {
                appState.contentInfo.contentsLoading[gid] = [:]
            }
            if appState.contentInfo.contentsLoadErrors[gid] == nil {
                appState.contentInfo.contentsLoadErrors[gid] = [:]
            }
            batchRange.forEach { appState.contentInfo.contentsLoadErrors[gid]?[$0] = nil }

            if appState.contentInfo.contentsLoading[gid]?[index] == true { break }
            batchRange.forEach { appState.contentInfo.contentsLoading[gid]?[$0] = true }

            let url = PersistenceController.fetchGallery(gid: gid)?.galleryURL ?? ""
            let galleryURL = Defaults.URL.detailPage(url: url, pageNum: pageNumber)
            appCommand = FetchThumbnailsCommand(gid: gid, index: index, url: galleryURL)
        case .fetchThumbnailsDone(let gid, let index, let result):
            let batchRange = appState.detailInfo.previewConfig.batchRange(index: index)
            switch result {
            case .success(let thumbnails):
                let thumbnailURL = thumbnails[index]?.safeURL()
                if thumbnailURL?.pathComponents.count ?? 0 >= 1, thumbnailURL?.pathComponents[1] == "mpv" {
                    dispatch(.fetchMPVKeys(gid: gid, index: index, mpvURL: thumbnailURL?.absoluteString ?? ""))
                } else {
                    dispatch(.fetchGalleryNormalContents(
                        gid: gid, index: index, thumbnails: thumbnails
                    ))
                    appState.contentInfo.update(gid: gid, thumbnails: thumbnails)
                    PersistenceController.update(gid: gid, thumbnails: thumbnails)
                }
            case .failure(let error):
                batchRange.forEach { index in
                    appState.contentInfo.contentsLoading[gid]?[index] = false
                    appState.contentInfo.contentsLoadErrors[gid]?[index] = error
                }
            }

        case .fetchGalleryNormalContents(let gid, let index, let thumbnails):
            appCommand = FetchGalleryNormalContentsCommand(
                gid: gid, index: index, thumbnails: thumbnails
            )
        case .fetchGalleryNormalContentsDone(let gid, let index, let result):
            let batchRange = appState.detailInfo.previewConfig.batchRange(index: index)
            batchRange.forEach { appState.contentInfo.contentsLoading[gid]?[$0] = false }

            switch result {
            case .success(let contents):
                appState.contentInfo.update(gid: gid, contents: contents)
                PersistenceController.update(gid: gid, contents: contents)
            case .failure(let error):
                batchRange.forEach { appState.contentInfo.contentsLoadErrors[gid]?[$0] = error }
            }

        case .refetchGalleryNormalContent(let gid, let index):
            let pageNumber = appState.detailInfo.previewConfig.pageNumber(index: index)
            appState.contentInfo.contentsLoadErrors[gid]?[index] = nil

            if appState.contentInfo.contentsLoading[gid]?[index] == true { break }
            appState.contentInfo.contentsLoading[gid]?[index] = true

            let url = PersistenceController.fetchGallery(gid: gid)?.galleryURL ?? ""
            let galleryURL = Defaults.URL.detailPage(url: url, pageNum: pageNumber)
            let thumbnailURL = appState.contentInfo.thumbnails[gid]?[index]
            let storedImageURL = appState.contentInfo.contents[gid]?[index] ?? ""
            appCommand = RefetchGalleryNormalContentCommand(
                gid: gid, index: index, galleryURL: galleryURL,
                thumbnailURL: thumbnailURL, storedImageURL: storedImageURL,
                bypassesSNIFiltering: appState.settings.setting.bypassesSNIFiltering
            )
        case .refetchGalleryNormalContentDone(let gid, let index, let result):
            appState.contentInfo.contentsLoading[gid]?[index] = false

            switch result {
            case .success(let content):
                appState.contentInfo.update(gid: gid, contents: content)
                PersistenceController.update(gid: gid, contents: content)
            case .failure(let error):
                appState.contentInfo.contentsLoadErrors[gid]?[index] = error
            }

        case .fetchGalleryMPVContent(let gid, let index, let isRefetch):
            guard let gidInteger = Int(gid),
                  let mpvKey = appState.contentInfo.mpvKeys[gid],
                  let imgKey = appState.contentInfo.mpvImageKeys[gid]?[index]
            else { break }

            appState.contentInfo.contentsLoadErrors[gid]?[index] = nil

            if appState.contentInfo.contentsLoading[gid]?[index] == true { break }
            appState.contentInfo.contentsLoading[gid]?[index] = true

            let reloadToken = isRefetch ? appState.contentInfo.mpvReloadTokens[gid]?[index] : nil
            appCommand = FetchGalleryMPVContentCommand(
                gid: gidInteger, index: index, mpvKey: mpvKey, imgKey: imgKey, reloadToken: reloadToken
            )
        case .fetchGalleryMPVContentDone(let gid, let index, let result):
            appState.contentInfo.contentsLoading[gid]?[index] = false

            if case .success(let (imageURL, reloadToken)) = result {
                appState.contentInfo.update(gid: gid, contents: [index: imageURL])
                PersistenceController.update(gid: gid, contents: [index: imageURL])
                if appState.contentInfo.mpvReloadTokens[gid] == nil {
                    appState.contentInfo.mpvReloadTokens[gid] = [index: reloadToken]
                } else {
                    appState.contentInfo.mpvReloadTokens[gid]?[index] = reloadToken
                }
            }

        // MARK: Account Ops
        case .createEhProfile(let name):
            appCommand = CreateEhProfileCommand(name: name)
        case .verifyEhProfile:
            appCommand = VerifyEhProfileCommand()
        case .verifyEhProfileDone(let result):
            if case .success(let (profileValue, profileNotFound)) = result {
                if let profileValue = profileValue {
                    let profileValueString = String(profileValue)
                    let hostURL = Defaults.URL.host.safeURL()
                    let selectedProfileKey = Defaults.Cookie.selectedProfile

                    let cookieValue = CookiesUtil.get(for: hostURL, key: selectedProfileKey)
                    if cookieValue.rawValue != profileValueString {
                        CookiesUtil.set(for: hostURL, key: selectedProfileKey, value: profileValueString)
                    }
                } else if profileNotFound {
                    dispatch(.createEhProfile(name: "EhPanda"))
                } else {
                    SwiftyBeaver.error("Found profile but failed in parsing value.")
                }
            }
        case .favorGallery(let gid, let favIndex):
            let token = PersistenceController.fetchGallery(gid: gid)?.token ?? ""
            appCommand = AddFavoriteCommand(gid: gid, token: token, favIndex: favIndex)
        case .unfavorGallery(let gid):
            appCommand = DeleteFavoriteCommand(gid: gid)

        case .rateGallery(let gid, let rating):
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

        case .commentGallery(let gid, let content):
            let galleryURL = PersistenceController.fetchGallery(gid: gid)?.galleryURL ?? ""
            appCommand = CommentCommand(gid: gid, content: content, galleryURL: galleryURL)
        case .editGalleryComment(let gid, let commentID, let content):
            let galleryURL = PersistenceController.fetchGallery(gid: gid)?.galleryURL ?? ""

            appCommand = EditCommentCommand(
                gid: gid,
                commentID: commentID,
                content: content,
                galleryURL: galleryURL
            )
        case .voteGalleryComment(let gid, let commentID, let vote):
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
