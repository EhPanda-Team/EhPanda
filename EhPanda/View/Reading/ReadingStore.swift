//
//  ReadingStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/22.
//

import SwiftUI
import Foundation
import ComposableArchitecture

struct ReadingState: Equatable {
    enum Route {
        case hud
        case readingSetting
    }

    @BindableState var route: Route?
    var galleryID = ""
    var readingProgress = 0
    var gallery: Gallery = .empty

    var contentLoadingStates = [Int: LoadingState]()
    var previewLoadingStates = [Int: LoadingState]()
    var previewConfig: PreviewConfig = .normal(rows: 4)

    var previews = [Int: String]()

    var thumbnails = [Int: String]()
    var contents = [Int: String]()
    var originalContents = [Int: String]()

    var mpvKey: String?
    var mpvImageKeys = [Int: String]()
    var mpvReloadTokens = [Int: String]()

    @BindableState var pageIndex = 0
    @BindableState var showsPanel = false
    @BindableState var sliderValue: Float = 1
    @BindableState var autoPlayPolicy: AutoPlayPolicy = .never

    var scaleAnchor: UnitPoint = .center
    var scale: CGFloat = 1
    var baseScale: CGFloat = 1
    var offset: CGSize = .zero
    var newOffset: CGSize = .zero

    func update<T>(stored: inout [Int: T], new: [Int: T], replaceExisting: Bool = true) {
        guard !new.isEmpty else { return }
        stored = stored.merging(new, uniquingKeysWith: { stored, new in replaceExisting ? new : stored })
    }
    mutating func updatePreviews(_ previews: [Int: String]) {
        update(stored: &self.previews, new: previews)
    }
    mutating func updateThumbnails(_ thumbnails: [Int: String]) {
        update(stored: &self.thumbnails, new: thumbnails)
    }
    mutating func updateContents(_ contents: [Int: String], _ originalContents: [Int: String]) {
        update(stored: &self.contents, new: contents)
        update(stored: &self.originalContents, new: originalContents)
    }

    func mapFromPager(setting: Setting, isLandscape: Bool) -> Int {
        guard isLandscape && setting.enablesDualPageMode
                && setting.readingDirection != .vertical
        else { return pageIndex + 1 }
        guard pageIndex > 0 else { return 1 }

        let result = setting.exceptCover ? pageIndex * 2 : pageIndex * 2 + 1

        if result + 1 == gallery.pageCount {
            return gallery.pageCount
        } else {
            return result
        }
    }
    func containerDataSource(setting: Setting, isLandscape: Bool) -> [Int] {
        let defaultData = Array(1...gallery.pageCount)
        guard isLandscape && setting.enablesDualPageMode
                && setting.readingDirection != .vertical
        else { return defaultData }

        let data = setting.exceptCover
            ? [1] + Array(stride(from: 2, through: gallery.pageCount, by: 2))
            : Array(stride(from: 1, through: gallery.pageCount, by: 2))

        return data
    }
    func imageContainerConfigs(index: Int, setting: Setting, isLandscape: Bool) -> (Int, Int, Bool, Bool) {
        let direction = setting.readingDirection
        let isReversed = direction == .rightToLeft
        let isFirstSingle = setting.exceptCover
        let isFirstPageAndSingle = index == 1 && isFirstSingle
        let isDualPage = isLandscape
        && setting.enablesDualPageMode
        && direction != .vertical

        let firstIndex = isDualPage && isReversed &&
            !isFirstPageAndSingle ? index + 1 : index
        let secondIndex = firstIndex + (isReversed ? -1 : 1)
        let isValidFirstRange =
            firstIndex >= 1 && firstIndex <= gallery.pageCount
        let isValidSecondRange = isFirstSingle
            ? secondIndex >= 2 && secondIndex <= gallery.pageCount
            : secondIndex >= 1 && secondIndex <= gallery.pageCount
        return (
            firstIndex, secondIndex, isValidFirstRange,
            !isFirstPageAndSingle && isValidSecondRange && isDualPage
        )
    }
}

enum ReadingAction: BindableAction {
    case binding(BindingAction<ReadingState>)
    case setNavigation(ReadingState.Route?)

    case toggleShowsPanel

    case copyImage(String)
    case saveImage(String)
    case shareImage(String)

    case onSingleTapGestureEnded
    case onDoubleTapGestureEnded
    case onMagnificationGestureChanged(CGFloat)
    case onMagnificationGestureEnded(CGFloat)
    case onDragGestureChanged(DragGesture.Value)
    case onDragGestureEnded(DragGesture.Value)

    case syncPreviews([Int: String])
    case syncThumbnails([Int: String])
    case syncContents([Int: String], [Int: String])

    case fetchDatabaseInfos(String)
    case fetchDatabaseInfosDone(GalleryState)

    case fetchPreviews(Int)
    case fetchPreviewsDone(Int, Result<[Int: String], AppError>)

    case fetchContents(Int)
    case refetchContents(Int)

    case fetchThumbnails(Int)
    case fetchThumbnailsDone(Int, Result<[Int: String], AppError>)
    case fetchNormalContents(Int, [Int: String])
    case fetchNormalContentsDone(Int, Result<([Int: String], [Int: String]), AppError>)
    case refetchNormalContents(Int)
    case refetchNormalContentsDone(Int, Result<[Int: String], AppError>)

    case fetchMPVKeys(Int, String)
    case fetchMPVKeysDone(Int, Result<(String, [Int: String]), AppError>)
    case fetchMPVContent(Int, Bool)
    case fetchMPVContentDone(Int, Result<(String, String?, String), AppError>)
}

struct ReadingEnvironment {
    let urlClient: URLClient
    let databaseClient: DatabaseClient
}

let readingReducer = Reducer<ReadingState, ReadingAction, ReadingEnvironment> { state, action, environment in
    switch action {
    case .binding:
        return .none

    case .setNavigation(let route):
        state.route = route
        return .none

    case .toggleShowsPanel:
        state.showsPanel.toggle()
        return .none

    case .copyImage(let imageURL):
        return .none

    case .saveImage(let imageURL):
        return .none

    case .shareImage(let imageURL):
        return .none

    case .onSingleTapGestureEnded:
        return .none

    case .onDoubleTapGestureEnded:
        return .none

    case .onMagnificationGestureChanged(let value):
        return .none

    case .onMagnificationGestureEnded(let value):
        return .none

    case .onDragGestureChanged(let value):
        return .none

    case .onDragGestureEnded(let value):
        return .none

    case .syncPreviews(let previews):
        guard !state.galleryID.isEmpty else { return .none }
        return environment.databaseClient
            .updatePreviews(gid: state.galleryID, previews: previews).fireAndForget()

    case .syncThumbnails(let thumbnails):
        guard !state.galleryID.isEmpty else { return .none }
        return environment.databaseClient
            .updateThumbnails(gid: state.galleryID, thumbnails: thumbnails).fireAndForget()

    case .syncContents(let contents, let originalContents):
        guard !state.galleryID.isEmpty else { return .none }
        return environment.databaseClient
            .updateContents(gid: state.galleryID, contents: contents, originalContents: originalContents)
            .fireAndForget()

    case .fetchDatabaseInfos(let gid):
        state.galleryID = gid
        state.gallery = environment.databaseClient.fetchGallery(gid)
        return environment.databaseClient.fetchGalleryState(gid).map(ReadingAction.fetchDatabaseInfosDone)

    case .fetchDatabaseInfosDone(let galleryState):
        if let previewConfig = galleryState.previewConfig {
            state.previewConfig = previewConfig
        }
        state.previews = galleryState.previews
        state.contents = galleryState.contents
        state.thumbnails = galleryState.thumbnails
        state.readingProgress = galleryState.readingProgress
        state.originalContents =  galleryState.originalContents
        return .none

    case .fetchPreviews(let index):
        guard state.previewLoadingStates[index] != .loading else { return .none }
        state.previewLoadingStates[index] = .loading
        let pageNum = state.previewConfig.pageNumber(index: index)
        return GalleryPreviewsRequest(galleryURL: state.gallery.galleryURL, pageNum: pageNum)
            .effect.map({ ReadingAction.fetchPreviewsDone(index, $0) })

    case .fetchPreviewsDone(let index, let result):
        switch result {
        case .success(let previews):
            guard !previews.isEmpty else {
                state.previewLoadingStates[index] = .failed(.notFound)
                return .none
            }
            state.previewLoadingStates[index] = .idle
            state.updatePreviews(previews)
            return .init(value: .syncPreviews(previews))
        case .failure(let error):
            state.previewLoadingStates[index] = .failed(error)
        }
        return .none

    case .fetchContents(let index):
        if state.mpvKey != nil {
            return .init(value: .fetchMPVContent(index, false))
        } else {
            return .init(value: .fetchThumbnails(index))
        }

    case .refetchContents(let index):
        if state.mpvKey != nil {
            return .init(value: .fetchMPVContent(index, true))
        } else {
            return .init(value: .refetchNormalContents(index))
        }

    case .fetchThumbnails(let index):
        guard state.contentLoadingStates[index] != .loading else { return .none }
        state.previewConfig.batchRange(index: index).forEach {
            state.contentLoadingStates[$0] = .loading
        }
        let pageNum = state.previewConfig.pageNumber(index: index)
        return ThumbnailsRequest(url: state.gallery.galleryURL, pageNum: pageNum)
            .effect.map({ ReadingAction.fetchThumbnailsDone(index, $0) })

    case .fetchThumbnailsDone(let index, let result):
        let batchRange = state.previewConfig.batchRange(index: index)
        switch result {
        case .success(let thumbnails):
            guard !thumbnails.isEmpty else {
                batchRange.forEach {
                    state.contentLoadingStates[$0] = .failed(.notFound)
                }
                return .none
            }
            if let urlString = thumbnails[index], environment.urlClient.checkIfMPVURL(URL(string: urlString)) {
                return .init(value: .fetchMPVKeys(index, urlString))
            } else {
                state.updateThumbnails(thumbnails)
                return .merge(
                    .init(value: .syncThumbnails(thumbnails)),
                    .init(value: .fetchNormalContents(index, thumbnails))
                )
            }
        case .failure(let error):
            batchRange.forEach {
                state.contentLoadingStates[$0] = .failed(error)
            }
        }
        return .none

    case .fetchNormalContents(let index, let thumbnails):
        return GalleryNormalContentsRequest(thumbnails: thumbnails)
            .effect.map({ ReadingAction.fetchNormalContentsDone(index, $0) })

    case .fetchNormalContentsDone(let index, let result):
        let batchRange = state.previewConfig.batchRange(index: index)
        switch result {
        case .success(let (contents, originalContents)):
            guard !contents.isEmpty else {
                batchRange.forEach {
                    state.contentLoadingStates[$0] = .failed(.notFound)
                }
                return .none
            }
            batchRange.forEach {
                state.contentLoadingStates[$0] = .idle
            }
            state.updateContents(contents, originalContents)
            return .init(value: .syncContents(contents, originalContents))
        case .failure(let error):
            batchRange.forEach {
                state.contentLoadingStates[$0] = .failed(error)
            }
        }
        return .none

    case .refetchNormalContents(let index):
        guard state.contentLoadingStates[index] != .loading else { return .none }
        state.contentLoadingStates[index] = .loading
        let pageNum = state.previewConfig.pageNumber(index: index)
        return GalleryNormalContentRefetchRequest(
            index: index, pageNum: pageNum,
            galleryURL: state.gallery.galleryURL,
            thumbnailURL: state.thumbnails[index],
            storedImageURL: state.contents[index] ?? ""
        )
        .effect.map({ ReadingAction.refetchNormalContentsDone(index, $0) })

    case .refetchNormalContentsDone(let index, let result):
        switch result {
        case .success(let contents):
            guard !contents.isEmpty else {
                state.contentLoadingStates[index] = .failed(.notFound)
                return .none
            }
            state.contentLoadingStates[index] = .idle
            state.updateContents(contents, [:])
            return .init(value: .syncContents(contents, [:]))
        case .failure(let error):
            state.contentLoadingStates[index] = .failed(error)
        }
        return .none

    case .fetchMPVKeys(let index, let mpvURL):
        return MPVKeysRequest(mpvURL: mpvURL)
            .effect.map({ ReadingAction.fetchMPVKeysDone(index, $0) })

    case .fetchMPVKeysDone(let index, let result):
        let batchRange = state.previewConfig.batchRange(index: index)
        switch result {
        case .success(let (mpvKey, mpvImageKeys)):
            let pageCount = state.gallery.pageCount
            guard mpvImageKeys.count == pageCount else {
                batchRange.forEach {
                    state.contentLoadingStates[$0] = .failed(.notFound)
                }
                return .none
            }
            batchRange.forEach {
                state.contentLoadingStates[$0] = .idle
            }
            state.mpvKey = mpvKey
            state.mpvImageKeys = mpvImageKeys
            return .merge(
                Array(1...min(3, max(1, pageCount))).map {
                    .init(value: .fetchMPVContent($0, false))
                }
            )
        case .failure(let error):
            batchRange.forEach {
                state.contentLoadingStates[$0] = .failed(error)
            }
        }
        return .none

    case .fetchMPVContent(let index, let isRefresh):
        guard let gidInteger = Int(state.galleryID), let mpvKey = state.mpvKey,
              let mpvImageKey = state.mpvImageKeys[index],
              state.contentLoadingStates[index] != .loading
        else { return .none }
        state.contentLoadingStates[index] = .loading
        let reloadToken = isRefresh ? state.mpvReloadTokens[index] : nil
        return GalleryMPVContentRequest(
            gid: gidInteger, index: index, mpvKey: mpvKey,
            mpvImageKey: mpvImageKey, reloadToken: reloadToken
        )
        .effect.map({ ReadingAction.fetchMPVContentDone(index, $0) })

    case .fetchMPVContentDone(let index, let result):
        switch result {
        case .success(let (content, originalContent, reloadToken)):
            let contents: [Int: String] = [index: content]
            var originalContents = [Int: String]()
            if let originalContent = originalContent {
                originalContents[index] = originalContent
            }
            state.contentLoadingStates[index] = .idle
            state.mpvReloadTokens[index] = reloadToken
            state.updateContents(contents, originalContents)
            return .init(value: .syncContents(contents, originalContents))
        case .failure(let error):
            state.contentLoadingStates[index] = .failed(error)
        }
        return .none
    }
}
.binding()
