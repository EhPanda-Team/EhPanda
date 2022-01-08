//
//  Store.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 2/12/26.
//

import SwiftUI
import Combine

final class DeprecatedStore: ObservableObject {
    @Published var appState = DeprecatedAppState()
    static var preview: DeprecatedStore = {
        let store = DeprecatedStore()
        store.appState.environment.isPreview = true
        return store
    }()

    func dispatch(_ action: DeprecatedAppAction) {
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

    private func privateDispatch(_ action: DeprecatedAppAction) {
        let description = String(describing: action)
        if description.contains("error") {
            Logger.error("[ACTION]: " + description)
        } else {
            switch action {
            case .fetchGalleryPreviewsDone(let gid, let pageNumber, let result):
                if case .success(let previews) = result {
                    Logger.verbose(
                        "[ACTION]: fetchGalleryPreviewsDone("
                        + "gid: \(gid), pageNumber: \(pageNumber), "
                        + "previews: \(previews.count))"
                    )
                }
            case .fetchThumbnailsDone(let gid, let index, let result):
                if case .success(let contents) = result {
                    Logger.verbose(
                        "[ACTION]: fetchThumbnailsDone("
                        + "gid: \(gid), index: \(index), "
                        + "contents: \(contents.count))"
                    )
                }
            case .fetchGalleryNormalContents(let gid, let index, let thumbnails):
                Logger.verbose(
                    "[ACTION]: fetchGalleryNormalContents("
                    + "gid: \(gid), index: \(index), "
                    + "thumbnails: \(thumbnails.count))"
                )
            case .fetchGalleryNormalContentsDone(let gid, let index, let result):
                if case .success(let (contents, originalContents)) = result {
                    Logger.verbose(
                        "[ACTION]: fetchGalleryNormalContentsDone("
                        + "gid: \(gid), index: \(index), "
                        + "contents: \(contents.count), "
                        + "originalContents: \(originalContents.count))"
                    )
                }
            case .fetchMPVKeysDone(let gid, let index, let result):
                if case .success(let (mpvKey, imgKeys)) = result {
                    Logger.verbose(
                        "[ACTION]: fetchMPVKeysDone("
                        + "gid: \(gid), index: \(index), "
                        + "mpvKey: \(mpvKey), imgKeys: \(imgKeys.count))"
                    )
                }
            default:
                Logger.verbose("[ACTION]: " + description)
            }
        }
        let (state, command) = reduce(state: appState, action: action)
        appState = state

        guard let command = command else { return }
        Logger.verbose("[COMMAND]: \(command)")
        command.execute(in: self)
    }

    func reduce(state: DeprecatedAppState, action: DeprecatedAppAction) -> (DeprecatedAppState, AppCommand?) {
        var appState = state
        var appCommand: AppCommand?

        switch action {
        // MARK: App Ops
        case .setReadingProgress(let gid, let tag):
            PersistenceController.update(gid: gid, readingProgress: tag)
        case .appendHistoryKeywords(let texts):
            appState.homeInfo.appendHistoryKeywords(texts: texts)
        case .removeHistoryKeyword(let text):
            appState.homeInfo.removeHistoryKeyword(text: text)
        case .clearHistoryKeywords:
            appState.homeInfo.historyKeywords = []
        case .setGalleryCommentJumpID(let gid):
            appState.environment.galleryItemReverseID = gid
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

        // MARK: Fetch Data
        case .fetchGalleryItemReverse(var url, let shouldParseGalleryURL):
            appState.environment.galleryItemReverseLoadFailed = false

            guard let tmpURL = URL(string: url),
                  tmpURL.pathComponents.count >= 4 else { break }
            if appState.environment.galleryItemReverseLoading { break }
            appState.environment.galleryItemReverseLoading = true

            if appState.settings.setting.redirectsLinksToSelectedHost {
                url = url.replacingOccurrences(
                    of: Defaults.URL.ehentai.absoluteString,
                    with: Defaults.URL.host.absoluteString
                )
                .replacingOccurrences(
                    of: Defaults.URL.exhentai.absoluteString,
                    with: Defaults.URL.host.absoluteString
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

        case .fetchGalleryDetail(let gid):
            appState.detailInfo.detailLoadErrors[gid] = nil

            if appState.detailInfo.detailLoading[gid] == true { break }
            appState.detailInfo.detailLoading[gid] = true

            let galleryURL = PersistenceController.fetchGallery(gid: gid)?.galleryURL ?? ""
            appCommand = FetchGalleryDetailCommand(gid: gid, galleryURL: galleryURL)
        case .fetchGalleryDetailDone(let gid, let result):
            appState.detailInfo.detailLoading[gid] = false

            switch result {
            case .success(let (detail, state, apiKey, _)):
                appState.settings.user.apikey = apiKey
//                if let greeting = greeting {
//                    appState.settings.insert(greeting: greeting)
//                }
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

        case .fetchGalleryPreviews/*(let gid, let index)*/:
            break
//            let pageNumber = appState.detailInfo.previewConfig.pageNumber(index: index)
//            if appState.detailInfo.previewsLoading[gid] == nil {
//                appState.detailInfo.previewsLoading[gid] = [:]
//            }
//
//            if appState.detailInfo.previewsLoading[gid]?[pageNumber] == true { break }
//            appState.detailInfo.previewsLoading[gid]?[pageNumber] = true
//
//            let galleryURL = PersistenceController.fetchGallery(gid: gid)?.galleryURL ?? ""
//            let url = URLUtil.detailPage(url: galleryURL, pageNum: pageNumber)
//            appCommand = FetchGalleryPreviewsCommand(gid: gid, url: url, pageNumber: pageNumber)

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

        case .fetchThumbnails/*(let gid, let index)*/:
            break
//            let batchRange = appState.detailInfo.previewConfig.batchRange(index: index)
//            let pageNumber = appState.detailInfo.previewConfig.pageNumber(index: index)
//            if appState.contentInfo.contentsLoading[gid] == nil {
//                appState.contentInfo.contentsLoading[gid] = [:]
//            }
//            if appState.contentInfo.contentsLoadErrors[gid] == nil {
//                appState.contentInfo.contentsLoadErrors[gid] = [:]
//            }
//            batchRange.forEach { appState.contentInfo.contentsLoadErrors[gid]?[$0] = nil }
//
//            if appState.contentInfo.contentsLoading[gid]?[index] == true { break }
//            batchRange.forEach { appState.contentInfo.contentsLoading[gid]?[$0] = true }
//
//            let url = PersistenceController.fetchGallery(gid: gid)?.galleryURL ?? ""
//            let galleryURL = URLUtil.detailPage(url: url, pageNum: pageNumber)
//            appCommand = FetchThumbnailsCommand(gid: gid, index: index, url: galleryURL)
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
            case .success(let (contents, originalContents)):
                appState.contentInfo.update(gid: gid, contents: contents, originalContents: originalContents)
                PersistenceController.update(gid: gid, contents: contents, originalContents: originalContents)
            case .failure(let error):
                batchRange.forEach { appState.contentInfo.contentsLoadErrors[gid]?[$0] = error }
            }

        case .refetchGalleryNormalContent/*(let gid, let index)*/:
            break
//            let pageNumber = appState.detailInfo.previewConfig.pageNumber(index: index)
//            appState.contentInfo.contentsLoadErrors[gid]?[index] = nil
//
//            if appState.contentInfo.contentsLoading[gid]?[index] == true { break }
//            appState.contentInfo.contentsLoading[gid]?[index] = true
//
//            let url = PersistenceController.fetchGallery(gid: gid)?.galleryURL ?? ""
//            let galleryURL = URLUtil.detailPage(url: url, pageNum: pageNumber)
//            let thumbnailURL = appState.contentInfo.thumbnails[gid]?[index]
//            let storedImageURL = appState.contentInfo.contents[gid]?[index] ?? ""
//            appCommand = RefetchGalleryNormalContentCommand(
//                gid: gid, index: index, galleryURL: galleryURL,
//                thumbnailURL: thumbnailURL, storedImageURL: storedImageURL,
//                bypassesSNIFiltering: appState.settings.setting.bypassesSNIFiltering
//            )
        case .refetchGalleryNormalContentDone(let gid, let index, let result):
            appState.contentInfo.contentsLoading[gid]?[index] = false

            switch result {
            case .success(let content):
                appState.contentInfo.update(gid: gid, contents: content, originalContents: [:])
                PersistenceController.update(gid: gid, contents: content, originalContents: [:])
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

            if case .success(let (imageURL, originalImageURL, reloadToken)) = result {
                var originalContents = [Int: String]()
                if let originalImageURL = originalImageURL {
                    originalContents[index] = originalImageURL
                }
                appState.contentInfo.update(gid: gid, contents: [index: imageURL], originalContents: originalContents)
                PersistenceController.update(gid: gid, contents: [index: imageURL], originalContents: originalContents)
                if appState.contentInfo.mpvReloadTokens[gid] == nil {
                    appState.contentInfo.mpvReloadTokens[gid] = [index: reloadToken]
                } else {
                    appState.contentInfo.mpvReloadTokens[gid]?[index] = reloadToken
                }
            }

        // MARK: Account Ops
        case .favorGallery(let gid, let favIndex):
            let token = PersistenceController.fetchGallery(gid: gid)?.token ?? ""
            appCommand = AddFavoriteCommand(gid: gid, token: token, favIndex: favIndex)
        case .unfavorGallery(let gid):
            appCommand = DeleteFavoriteCommand(gid: gid)

        case .rateGallery(let gid, let rating):
            let apiuidString = "" // appState.settings.user.apiuid
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
            let apiuidString = "" // appState.settings.user.apiuid
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
