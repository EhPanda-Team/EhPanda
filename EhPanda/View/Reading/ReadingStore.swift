//
//  ReadingStore.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/22.
//

import SwiftUI
import TTProgressHUD
import ComposableArchitecture

struct ReadingState: Equatable {
    enum Route: Equatable {
        case hud
        case share(UIImage)
        case readingSetting
    }
    enum ImageAction {
        case copy
        case save
        case share
    }
    struct CancelID: Hashable {
        let id = String(describing: ReadingState.CancelID.self)
    }

    @BindableState var route: Route?
    let gallery: Gallery

    var readingProgress: Int = .zero
    var forceRefreshID: UUID = .init()
    var hudConfig: TTProgressHUDConfig = .loading

    var imageURLLoadingStates = [Int: LoadingState]()
    var previewLoadingStates = [Int: LoadingState]()
    var databaseLoadingState: LoadingState = .loading
    var previewConfig: PreviewConfig = .normal(rows: 4)

    var previewURLs = [Int: URL]()

    var thumbnailURLs = [Int: URL]()
    var imageURLs = [Int: URL]()
    var originalImageURLs = [Int: URL]()

    var mpvKey: String?
    var mpvImageKeys = [Int: String]()
    var mpvSkipServerIdentifiers = [Int: String]()

    @BindableState var showsPanel = false
    @BindableState var showsSliderPreview = false

    // Update
    func update<T>(stored: inout [Int: T], new: [Int: T], replaceExisting: Bool = true) {
        guard !new.isEmpty else { return }
        stored = stored.merging(new, uniquingKeysWith: { stored, new in replaceExisting ? new : stored })
    }
    mutating func updatePreviewURLs(_ previewURLs: [Int: URL]) {
        update(stored: &self.previewURLs, new: previewURLs)
    }
    mutating func updateThumbnailURLs(_ thumbnailURLs: [Int: URL]) {
        update(stored: &self.thumbnailURLs, new: thumbnailURLs)
    }
    mutating func updateImageURLs(_ imageURLs: [Int: URL], _ originalImageURLs: [Int: URL]) {
        update(stored: &self.imageURLs, new: imageURLs)
        update(stored: &self.originalImageURLs, new: originalImageURLs)
    }

    // Image
    func containerDataSource(setting: Setting, isLandscape: Bool = DeviceUtil.isLandscape) -> [Int] {
        let defaultData = Array(1...gallery.pageCount)
        guard isLandscape && setting.enablesDualPageMode
                && setting.readingDirection != .vertical
        else { return defaultData }

        let data = setting.exceptCover
            ? [1] + Array(stride(from: 2, through: gallery.pageCount, by: 2))
            : Array(stride(from: 1, through: gallery.pageCount, by: 2))

        return data
    }
    func imageContainerConfigs(
        index: Int, setting: Setting, isLandscape: Bool = DeviceUtil.isLandscape
    ) -> ImageStackConfig {
        let direction = setting.readingDirection
        let isReversed = direction == .rightToLeft
        let isFirstSingle = setting.exceptCover
        let isFirstPageAndSingle = index == 1 && isFirstSingle
        let isDualPage = isLandscape && setting.enablesDualPageMode && direction != .vertical
        let firstIndex = isDualPage && isReversed && !isFirstPageAndSingle ? index + 1 : index
        let secondIndex = firstIndex + (isReversed ? -1 : 1)
        let isValidFirstRange = firstIndex >= 1 && firstIndex <= gallery.pageCount
        let isValidSecondRange = isFirstSingle
            ? secondIndex >= 2 && secondIndex <= gallery.pageCount
            : secondIndex >= 1 && secondIndex <= gallery.pageCount
        return .init(
            firstIndex: firstIndex, secondIndex: secondIndex, isFirstAvailable: isValidFirstRange,
            isSecondAvailable: !isFirstPageAndSingle && isValidSecondRange && isDualPage
        )
    }
}

enum ReadingAction: BindableAction {
    case binding(BindingAction<ReadingState>)
    case setNavigation(ReadingState.Route?)

    case toggleShowsPanel
    case setOrientationPortrait(Bool)
    case onPerformDismiss
    case onAppear(Bool)

    case onWebImageRetry(Int)
    case onWebImageSucceeded(Int)
    case onWebImageFailed(Int)
    case reloadAllWebImages
    case retryAllFailedWebImages

    case copyImage(URL)
    case saveImage(URL)
    case saveImageDone(Bool)
    case shareImage(URL)
    case fetchImage(ReadingState.ImageAction, URL)
    case fetchImageDone(ReadingState.ImageAction, Result<UIImage, Error>)

    case syncReadingProgress(Int)
    case syncPreviewURLs([Int: URL])
    case syncThumbnailURLs([Int: URL])
    case syncImageURLs([Int: URL], [Int: URL])

    case teardown
    case fetchDatabaseInfos
    case fetchDatabaseInfosDone(GalleryState)

    case fetchPreviewURLs(Int)
    case fetchPreviewURLsDone(Int, Result<[Int: URL], AppError>)

    case fetchImageURLs(Int)
    case refetchImageURLs(Int)
    case prefetchImages(Int, Int)

    case fetchThumbnailURLs(Int)
    case fetchThumbnailURLsDone(Int, Result<[Int: URL], AppError>)
    case fetchNormalImageURLs(Int, [Int: URL])
    case fetchNormalImageURLsDone(Int, Result<([Int: URL], [Int: URL]), AppError>)
    case refetchNormalImageURLs(Int)
    case refetchNormalImageURLsDone(Int, Result<([Int: URL], HTTPURLResponse?), AppError>)

    case fetchMPVKeys(Int, URL)
    case fetchMPVKeysDone(Int, Result<(String, [Int: String]), AppError>)
    case fetchMPVImageURL(Int, Bool)
    case fetchMPVImageURLDone(Int, Result<(URL, URL?, String), AppError>)
}

struct ReadingEnvironment {
    let urlClient: URLClient
    let imageClient: ImageClient
    let deviceClient: DeviceClient
    let hapticClient: HapticClient
    let cookiesClient: CookiesClient
    let databaseClient: DatabaseClient
    let clipboardClient: ClipboardClient
    let appDelegateClient: AppDelegateClient
}

let readingReducer = Reducer<ReadingState, ReadingAction, ReadingEnvironment> { state, action, environment in
    switch action {
    case .binding(\.$showsSliderPreview):
        return environment.hapticClient.generateFeedback(.soft).fireAndForget()

    case .binding:
        return .none

    case .setNavigation(let route):
        state.route = route
        return .none

    case .toggleShowsPanel:
        state.showsPanel.toggle()
        return .none

    case .setOrientationPortrait(let isPortrait):
        var effects = [Effect<ReadingAction, Never>]()
        if isPortrait {
            effects.append(environment.appDelegateClient.setPortraitOrientationMask().fireAndForget())
            effects.append(environment.appDelegateClient.setPortraitOrientation().fireAndForget())
        } else {
            effects.append(environment.appDelegateClient.setAllOrientationMask().fireAndForget())
        }
        return .merge(effects)

    case .onPerformDismiss:
        return environment.hapticClient.generateFeedback(.light).fireAndForget()

    case .onAppear(let enablesLandscape):
        var effects: [Effect<ReadingAction, Never>] = [
            .init(value: .fetchDatabaseInfos)
        ]
        if enablesLandscape {
            effects.append(.init(value: .setOrientationPortrait(false)))
        }
        return .merge(effects)

    case .onWebImageRetry(let index):
        state.imageURLLoadingStates[index] = .idle
        return .none

    case .onWebImageSucceeded(let index):
        state.imageURLLoadingStates[index] = .idle
        return .none

    case .onWebImageFailed(let index):
        state.imageURLLoadingStates[index] = .failed(.webImageFailed)
        return .none

    case .reloadAllWebImages:
        state.previewURLs = .init()
        state.thumbnailURLs = .init()
        state.imageURLs = .init()
        state.originalImageURLs = .init()
        state.mpvKey = nil
        state.mpvImageKeys = .init()
        state.mpvSkipServerIdentifiers = .init()
        state.forceRefreshID = .init()
        return environment.databaseClient.removeImageURLs(gid: state.gallery.id).fireAndForget()

    case .retryAllFailedWebImages:
        state.imageURLLoadingStates.forEach { (index, loadingState) in
            if case .failed = loadingState {
                state.imageURLLoadingStates[index] = .idle
            }
        }
        state.previewLoadingStates.forEach { (index, loadingState) in
            if case .failed = loadingState {
                state.previewLoadingStates[index] = .idle
            }
        }
        return .none

    case .copyImage(let imageURL):
        return .init(value: .fetchImage(.copy, imageURL))

    case .saveImage(let imageURL):
        return .init(value: .fetchImage(.save, imageURL))

    case .saveImageDone(let isSucceeded):
        state.hudConfig = isSucceeded ? .savedToPhotoLibrary : .error
        return .init(value: .setNavigation(.hud))

    case .shareImage(let imageURL):
        return .init(value: .fetchImage(.share, imageURL))

    case .fetchImage(let action, let imageURL):
        return environment.imageClient.fetchImage(url: imageURL)
            .map({ ReadingAction.fetchImageDone(action, $0) })
            .cancellable(id: ReadingState.CancelID())

    case .fetchImageDone(let action, let result):
        if case .success(let image) = result {
            switch action {
            case .copy:
                state.hudConfig = .copiedToClipboardSucceeded
                return .merge(
                    .init(value: .setNavigation(.hud)),
                    environment.clipboardClient.saveImage(image).fireAndForget()
                )
            case .save:
                return environment.imageClient
                    .saveImageToPhotoLibrary(image).map(ReadingAction.saveImageDone)
            case .share:
                return .init(value: .setNavigation(.share(image)))
            }
        } else {
            state.hudConfig = .error
            return .init(value: .setNavigation(.hud))
        }

    case .syncReadingProgress(let progress):
        return environment.databaseClient
            .updateReadingProgress(gid: state.gallery.id, progress: progress).fireAndForget()

    case .syncPreviewURLs(let previewURLs):
        return environment.databaseClient
            .updatePreviewURLs(gid: state.gallery.id, previewURLs: previewURLs).fireAndForget()

    case .syncThumbnailURLs(let thumbnailURLs):
        return environment.databaseClient
            .updateThumbnailURLs(gid: state.gallery.id, thumbnailURLs: thumbnailURLs).fireAndForget()

    case .syncImageURLs(let imageURLs, let originalImageURLs):
        return environment.databaseClient
            .updateImageURLs(gid: state.gallery.id, imageURLs: imageURLs, originalImageURLs: originalImageURLs)
            .fireAndForget()

    case .teardown:
        var effects: [Effect<ReadingAction, Never>] = [
            .cancel(id: ReadingState.CancelID())
        ]
        if !environment.deviceClient.isPad() {
            effects.append(.init(value: .setOrientationPortrait(true)))
        }
        return .merge(effects)

    case .fetchDatabaseInfos:
        return environment.databaseClient.fetchGalleryState(gid: state.gallery.id)
            .map(ReadingAction.fetchDatabaseInfosDone).cancellable(id: ReadingState.CancelID())

    case .fetchDatabaseInfosDone(let galleryState):
        if let previewConfig = galleryState.previewConfig {
            state.previewConfig = previewConfig
        }
        state.previewURLs = galleryState.previewURLs
        state.imageURLs = galleryState.imageURLs
        state.thumbnailURLs = galleryState.thumbnailURLs
        state.originalImageURLs =  galleryState.originalImageURLs
        state.readingProgress = galleryState.readingProgress
        state.databaseLoadingState = .idle
        return .none

    case .fetchPreviewURLs(let index):
        guard state.previewLoadingStates[index] != .loading,
              let galleryURL = state.gallery.galleryURL
        else { return .none }
        state.previewLoadingStates[index] = .loading
        let pageNum = state.previewConfig.pageNumber(index: index)
        return GalleryPreviewURLsRequest(galleryURL: galleryURL, pageNum: pageNum)
            .effect.map({ ReadingAction.fetchPreviewURLsDone(index, $0) }).cancellable(id: ReadingState.CancelID())

    case .fetchPreviewURLsDone(let index, let result):
        switch result {
        case .success(let previewURLs):
            guard !previewURLs.isEmpty else {
                state.previewLoadingStates[index] = .failed(.notFound)
                return .none
            }
            state.previewLoadingStates[index] = .idle
            state.updatePreviewURLs(previewURLs)
            return .init(value: .syncPreviewURLs(previewURLs))
        case .failure(let error):
            state.previewLoadingStates[index] = .failed(error)
        }
        return .none

    case .fetchImageURLs(let index):
        if state.mpvKey != nil {
            return .init(value: .fetchMPVImageURL(index, false))
        } else {
            return .init(value: .fetchThumbnailURLs(index))
        }

    case .refetchImageURLs(let index):
        if state.mpvKey != nil {
            return .init(value: .fetchMPVImageURL(index, true))
        } else {
            return .init(value: .refetchNormalImageURLs(index))
        }

    case .prefetchImages(let index, let prefetchLimit):
        func getPrefetchImageURLs(range: ClosedRange<Int>) -> [URL] {
            (range.lowerBound...range.upperBound).compactMap { index in
                if let url = state.imageURLs[index] {
                    return url
                }
                return nil
            }
        }
        func getFetchImageURLIndices(range: ClosedRange<Int>) -> [Int] {
            (range.lowerBound...range.upperBound).compactMap { index in
                if state.imageURLs[index] == nil, state.imageURLLoadingStates[index] != .loading {
                    return index
                }
                return nil
            }
        }
        var prefetchImageURLs = [URL]()
        var fetchImageURLIndices = [Int]()
        var effects = [Effect<ReadingAction, Never>]()
        let previousUpperBound = max(index - 2, 1)
        let previousLowerBound = max(previousUpperBound - prefetchLimit / 2, 1)
        if previousUpperBound - previousLowerBound > 0 {
            prefetchImageURLs += getPrefetchImageURLs(range: previousLowerBound...previousUpperBound)
            fetchImageURLIndices += getFetchImageURLIndices(range: previousLowerBound...previousUpperBound)
        }
        let nextLowerBound = min(index + 2, state.gallery.pageCount)
        let nextUpperBound = min(nextLowerBound + prefetchLimit / 2, state.gallery.pageCount)
        if nextUpperBound - nextLowerBound > 0 {
            prefetchImageURLs += getPrefetchImageURLs(range: nextLowerBound...nextUpperBound)
            fetchImageURLIndices += getFetchImageURLIndices(range: nextLowerBound...nextUpperBound)
        }
        fetchImageURLIndices.forEach {
            effects.append(.init(value: .fetchImageURLs($0)))
        }
        effects.append(environment.imageClient.prefetchImages(prefetchImageURLs).fireAndForget())
        return .merge(effects)

    case .fetchThumbnailURLs(let index):
        guard state.imageURLLoadingStates[index] != .loading,
              let galleryURL = state.gallery.galleryURL
        else { return .none }
        state.previewConfig.batchRange(index: index).forEach {
            state.imageURLLoadingStates[$0] = .loading
        }
        let pageNum = state.previewConfig.pageNumber(index: index)
        return ThumbnailURLsRequest(galleryURL: galleryURL, pageNum: pageNum)
            .effect.map({ ReadingAction.fetchThumbnailURLsDone(index, $0) }).cancellable(id: ReadingState.CancelID())

    case .fetchThumbnailURLsDone(let index, let result):
        let batchRange = state.previewConfig.batchRange(index: index)
        switch result {
        case .success(let thumbnailURLs):
            guard !thumbnailURLs.isEmpty else {
                batchRange.forEach {
                    state.imageURLLoadingStates[$0] = .failed(.notFound)
                }
                return .none
            }
            if let url = thumbnailURLs[index], environment.urlClient.checkIfMPVURL(url) {
                return .init(value: .fetchMPVKeys(index, url))
            } else {
                state.updateThumbnailURLs(thumbnailURLs)
                return .merge(
                    .init(value: .syncThumbnailURLs(thumbnailURLs)),
                    .init(value: .fetchNormalImageURLs(index, thumbnailURLs))
                )
            }
        case .failure(let error):
            batchRange.forEach {
                state.imageURLLoadingStates[$0] = .failed(error)
            }
        }
        return .none

    case .fetchNormalImageURLs(let index, let thumbnailURLs):
        return GalleryNormalImageURLsRequest(thumbnailURLs: thumbnailURLs)
            .effect.map({ ReadingAction.fetchNormalImageURLsDone(index, $0) }).cancellable(id: ReadingState.CancelID())

    case .fetchNormalImageURLsDone(let index, let result):
        let batchRange = state.previewConfig.batchRange(index: index)
        switch result {
        case .success(let (imageURLs, originalImageURLs)):
            guard !imageURLs.isEmpty else {
                batchRange.forEach {
                    state.imageURLLoadingStates[$0] = .failed(.notFound)
                }
                return .none
            }
            batchRange.forEach {
                state.imageURLLoadingStates[$0] = .idle
            }
            state.updateImageURLs(imageURLs, originalImageURLs)
            return .init(value: .syncImageURLs(imageURLs, originalImageURLs))
        case .failure(let error):
            batchRange.forEach {
                state.imageURLLoadingStates[$0] = .failed(error)
            }
        }
        return .none

    case .refetchNormalImageURLs(let index):
        guard state.imageURLLoadingStates[index] != .loading,
              let galleryURL = state.gallery.galleryURL,
              let imageURL = state.imageURLs[index]
        else { return .none }
        state.imageURLLoadingStates[index] = .loading
        let pageNum = state.previewConfig.pageNumber(index: index)
        return GalleryNormalImageURLRefetchRequest(
            index: index, pageNum: pageNum,
            galleryURL: galleryURL,
            thumbnailURL: state.thumbnailURLs[index],
            storedImageURL: imageURL
        )
        .effect.map({ ReadingAction.refetchNormalImageURLsDone(index, $0) }).cancellable(id: ReadingState.CancelID())

    case .refetchNormalImageURLsDone(let index, let result):
        switch result {
        case .success(let (imageURLs, response)):
            var effects = [Effect<ReadingAction, Never>]()
            if let response = response {
                effects.append(environment.cookiesClient.setSkipServer(response: response).fireAndForget())
            }
            guard !imageURLs.isEmpty else {
                state.imageURLLoadingStates[index] = .failed(.notFound)
                return effects.isEmpty ? .none : .merge(effects)
            }
            state.imageURLLoadingStates[index] = .idle
            state.updateImageURLs(imageURLs, [:])
            effects.append(.init(value: .syncImageURLs(imageURLs, [:])))
            return .merge(effects)
        case .failure(let error):
            state.imageURLLoadingStates[index] = .failed(error)
        }
        return .none

    case .fetchMPVKeys(let index, let mpvURL):
        return MPVKeysRequest(mpvURL: mpvURL)
            .effect.map({ ReadingAction.fetchMPVKeysDone(index, $0) }).cancellable(id: ReadingState.CancelID())

    case .fetchMPVKeysDone(let index, let result):
        let batchRange = state.previewConfig.batchRange(index: index)
        switch result {
        case .success(let (mpvKey, mpvImageKeys)):
            let pageCount = state.gallery.pageCount
            guard mpvImageKeys.count == pageCount else {
                batchRange.forEach {
                    state.imageURLLoadingStates[$0] = .failed(.notFound)
                }
                return .none
            }
            batchRange.forEach {
                state.imageURLLoadingStates[$0] = .idle
            }
            state.mpvKey = mpvKey
            state.mpvImageKeys = mpvImageKeys
            return .merge(
                Array(1...min(3, max(1, pageCount))).map {
                    .init(value: .fetchMPVImageURL($0, false))
                }
            )
        case .failure(let error):
            batchRange.forEach {
                state.imageURLLoadingStates[$0] = .failed(error)
            }
        }
        return .none

    case .fetchMPVImageURL(let index, let isRefresh):
        guard let gidInteger = Int(state.gallery.id), let mpvKey = state.mpvKey,
              let mpvImageKey = state.mpvImageKeys[index],
              state.imageURLLoadingStates[index] != .loading
        else { return .none }
        state.imageURLLoadingStates[index] = .loading
        let skipServerIdentifier = isRefresh ? state.mpvSkipServerIdentifiers[index] : nil
        return GalleryMPVImageURLRequest(
            gid: gidInteger, index: index, mpvKey: mpvKey,
            mpvImageKey: mpvImageKey, skipServerIdentifier: skipServerIdentifier
        )
        .effect.map({ ReadingAction.fetchMPVImageURLDone(index, $0) }).cancellable(id: ReadingState.CancelID())

    case .fetchMPVImageURLDone(let index, let result):
        switch result {
        case .success(let (imageURL, originalImageURL, skipServerIdentifier)):
            let imageURLs: [Int: URL] = [index: imageURL]
            var originalImageURLs = [Int: URL]()
            if let originalImageURL = originalImageURL {
                originalImageURLs[index] = originalImageURL
            }
            state.imageURLLoadingStates[index] = .idle
            state.mpvSkipServerIdentifiers[index] = skipServerIdentifier
            state.updateImageURLs(imageURLs, originalImageURLs)
            return .init(value: .syncImageURLs(imageURLs, originalImageURLs))
        case .failure(let error):
            state.imageURLLoadingStates[index] = .failed(error)
        }
        return .none
    }
}
.haptics(
    unwrapping: \.route,
    case: /ReadingState.Route.readingSetting,
    hapticClient: \.hapticClient
)
.haptics(
    unwrapping: \.route,
    case: /ReadingState.Route.share,
    hapticClient: \.hapticClient
)
.binding()
