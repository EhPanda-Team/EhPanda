//
//  ReadingReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/22.
//

import SwiftUI
import TTProgressHUD
import ComposableArchitecture

@Reducer
struct ReadingReducer {
    @CasePathable
    enum Route: Equatable {
        case hud
        case share(IdentifiableBox<ShareItem>)
        case readingSetting(EquatableVoid = .init())
    }

    enum ShareItem: Equatable {
        var associatedValue: Any {
            switch self {
            case .data(let data):
                return data
            case .image(let image):
                return image
            }
        }
        case data(Data)
        case image(UIImage)
    }

    enum ImageAction {
        case copy(Bool)
        case save(Bool)
        case share(Bool)
    }

    private enum CancelID: CaseIterable {
        case fetchImage
        case fetchDatabaseInfos
        case fetchPreviewURLs
        case fetchThumbnailURLs
        case fetchNormalImageURLs
        case refetchNormalImageURLs
        case fetchMPVKeys
        case fetchMPVImageURL
    }

    @ObservableState
    struct State: Equatable {
        var route: Route?
        var gallery: Gallery = .empty
        var galleryDetail: GalleryDetail?

        var readingProgress: Int = .zero
        var forceRefreshID: UUID = .init()
        var hudConfig: TTProgressHUDConfig = .loading

        var webImageLoadSuccessIndices = Set<Int>()
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

        var showsPanel = false
        var showsSliderPreview = false

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

    enum Action: BindableAction {
        case binding(BindingAction<State>)
        case setNavigation(Route?)

        case toggleShowsPanel
        case setOrientationPortrait(Bool)
        case onPerformDismiss
        case onAppear(String, Bool)

        case onWebImageRetry(Int)
        case onWebImageSucceeded(Int)
        case onWebImageFailed(Int)
        case reloadAllWebImages
        case retryAllFailedWebImages

        case copyImage(URL)
        case saveImage(URL)
        case saveImageDone(Bool)
        case shareImage(URL)
        case fetchImage(ImageAction, URL)
        case fetchImageDone(ImageAction, Result<UIImage, Error>)

        case syncReadingProgress(Int)
        case syncPreviewURLs([Int: URL])
        case syncThumbnailURLs([Int: URL])
        case syncImageURLs([Int: URL], [Int: URL])

        case teardown
        case fetchDatabaseInfos(String)
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

    @Dependency(\.appDelegateClient) private var appDelegateClient
    @Dependency(\.clipboardClient) private var clipboardClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.cookieClient) private var cookieClient
    @Dependency(\.deviceClient) private var deviceClient
    @Dependency(\.imageClient) private var imageClient
    @Dependency(\.urlClient) private var urlClient

    var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.showsSliderPreview) { _, _ in
                Reduce({ _, _ in .run(operation: { _ in hapticsClient.generateFeedback(.soft) }) })
            }

        Reduce { state, action in
            switch action {
            case .binding:
                return .none

            case .setNavigation(let route):
                state.route = route
                return .none

            case .toggleShowsPanel:
                state.showsPanel.toggle()
                return .none

            case .setOrientationPortrait(let isPortrait):
                var effects = [Effect<Action>]()
                if isPortrait {
                    effects.append(.run(operation: { _ in appDelegateClient.setPortraitOrientationMask() }))
                    effects.append(.run(operation: { _ in await appDelegateClient.setPortraitOrientation() }))
                } else {
                    effects.append(.run(operation: { _ in appDelegateClient.setAllOrientationMask() }))
                }
                return .merge(effects)

            case .onPerformDismiss:
                return .run(operation: { _ in hapticsClient.generateFeedback(.light) })

            case .onAppear(let gid, let enablesLandscape):
                var effects: [Effect<Action>] = [
                    .send(.fetchDatabaseInfos(gid))
                ]
                if enablesLandscape {
                    effects.append(.send(.setOrientationPortrait(false)))
                }
                return .merge(effects)

            case .onWebImageRetry(let index):
                state.imageURLLoadingStates[index] = .idle
                return .none

            case .onWebImageSucceeded(let index):
                state.imageURLLoadingStates[index] = .idle
                state.webImageLoadSuccessIndices.insert(index)
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
                return .run { [state] _ in
                    await databaseClient.removeImageURLs(gid: state.gallery.id)
                }

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
                return .send(.fetchImage(.copy(imageURL.isGIF), imageURL))

            case .saveImage(let imageURL):
                return .send(.fetchImage(.save(imageURL.isGIF), imageURL))

            case .saveImageDone(let isSucceeded):
                state.hudConfig = isSucceeded ? .savedToPhotoLibrary : .error
                return .send(.setNavigation(.hud))

            case .shareImage(let imageURL):
                return .send(.fetchImage(.share(imageURL.isGIF), imageURL))

            case .fetchImage(let action, let imageURL):
                return .run { send in
                    let result = await imageClient.fetchImage(url: imageURL)
                    await send(.fetchImageDone(action, result))
                }
                .cancellable(id: CancelID.fetchImage)

            case .fetchImageDone(let action, let result):
                if case .success(let image) = result {
                    switch action {
                    case .copy(let isAnimated):
                        state.hudConfig = .copiedToClipboardSucceeded
                        return .merge(
                            .send(.setNavigation(.hud)),
                            .run(operation: { _ in clipboardClient.saveImage(image, isAnimated) })
                        )
                    case .save(let isAnimated):
                        return .run { send in
                            let success = await imageClient.saveImageToPhotoLibrary(image, isAnimated)
                            await send(.saveImageDone(success))
                        }
                    case .share(let isAnimated):
                        if isAnimated, let data = image.kf.data(format: .GIF) {
                            return .send(.setNavigation(.share(.init(value: .data(data)))))
                        } else {
                            return .send(.setNavigation(.share(.init(value: .image(image)))))
                        }
                    }
                } else {
                    state.hudConfig = .error
                    return .send(.setNavigation(.hud))
                }

            case .syncReadingProgress(let progress):
                return .run { [state] _ in
                    await databaseClient.updateReadingProgress(gid: state.gallery.id, progress: progress)
                }

            case .syncPreviewURLs(let previewURLs):
                return .run { [state] _ in
                    await databaseClient.updatePreviewURLs(gid: state.gallery.id, previewURLs: previewURLs)
                }

            case .syncThumbnailURLs(let thumbnailURLs):
                return .run { [state] _ in
                    await databaseClient.updateThumbnailURLs(gid: state.gallery.id, thumbnailURLs: thumbnailURLs)
                }

            case .syncImageURLs(let imageURLs, let originalImageURLs):
                return .run { [state] _ in
                    await databaseClient.updateImageURLs(
                        gid: state.gallery.id,
                        imageURLs: imageURLs,
                        originalImageURLs: originalImageURLs
                    )
                }

            case .teardown:
                var effects: [Effect<Action>] = [
                    .merge(CancelID.allCases.map(Effect.cancel(id:)))
                ]
                if !deviceClient.isPad() {
                    effects.append(.send(.setOrientationPortrait(true)))
                }
                return .merge(effects)

            case .fetchDatabaseInfos(let gid):
                guard let gallery = databaseClient.fetchGallery(gid: gid) else { return .none }
                state.gallery = gallery
                state.galleryDetail = databaseClient.fetchGalleryDetail(gid: state.gallery.id)
                return .run { [state] send in
                    guard let dbState = await databaseClient.fetchGalleryState(gid: state.gallery.id) else { return }
                    await send(.fetchDatabaseInfosDone(dbState))
                }
                .cancellable(id: CancelID.fetchDatabaseInfos)

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
                return .run { send in
                    let response = await GalleryPreviewURLsRequest(galleryURL: galleryURL, pageNum: pageNum).response()
                    await send(.fetchPreviewURLsDone(index, response))
                }
                .cancellable(id: CancelID.fetchPreviewURLs)

            case .fetchPreviewURLsDone(let index, let result):
                switch result {
                case .success(let previewURLs):
                    guard !previewURLs.isEmpty else {
                        state.previewLoadingStates[index] = .failed(.notFound)
                        return .none
                    }
                    state.previewLoadingStates[index] = .idle
                    state.updatePreviewURLs(previewURLs)
                    return .send(.syncPreviewURLs(previewURLs))
                case .failure(let error):
                    state.previewLoadingStates[index] = .failed(error)
                }
                return .none

            case .fetchImageURLs(let index):
                if state.mpvKey != nil {
                    return .send(.fetchMPVImageURL(index, false))
                } else {
                    return .send(.fetchThumbnailURLs(index))
                }

            case .refetchImageURLs(let index):
                if state.mpvKey != nil {
                    return .send(.fetchMPVImageURL(index, true))
                } else {
                    return .send(.refetchNormalImageURLs(index))
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
                var effects = [Effect<Action>]()
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
                    effects.append(.send(.fetchImageURLs($0)))
                }
                effects.append(
                    .run { [prefetchImageURLs] _ in
                        imageClient.prefetchImages(prefetchImageURLs)
                    }
                )
                return .merge(effects)

            case .fetchThumbnailURLs(let index):
                guard state.imageURLLoadingStates[index] != .loading,
                      let galleryURL = state.gallery.galleryURL
                else { return .none }
                state.previewConfig.batchRange(index: index).forEach {
                    state.imageURLLoadingStates[$0] = .loading
                }
                let pageNum = state.previewConfig.pageNumber(index: index)
                return .run { send in
                    let response = await ThumbnailURLsRequest(galleryURL: galleryURL, pageNum: pageNum).response()
                    await send(.fetchThumbnailURLsDone(index, response))
                }
                .cancellable(id: CancelID.fetchThumbnailURLs)

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
                    if let url = thumbnailURLs[index], urlClient.checkIfMPVURL(url) {
                        return .send(.fetchMPVKeys(index, url))
                    } else {
                        state.updateThumbnailURLs(thumbnailURLs)
                        return .merge(
                            .send(.syncThumbnailURLs(thumbnailURLs)),
                            .send(.fetchNormalImageURLs(index, thumbnailURLs))
                        )
                    }
                case .failure(let error):
                    batchRange.forEach {
                        state.imageURLLoadingStates[$0] = .failed(error)
                    }
                }
                return .none

            case .fetchNormalImageURLs(let index, let thumbnailURLs):
                return .run { send in
                    let response = await GalleryNormalImageURLsRequest(thumbnailURLs: thumbnailURLs).response()
                    await send(.fetchNormalImageURLsDone(index, response))
                }
                .cancellable(id: CancelID.fetchNormalImageURLs)

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
                    return .send(.syncImageURLs(imageURLs, originalImageURLs))
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
                return .run { [thumbnailURL = state.thumbnailURLs[index]] send in
                    let response = await GalleryNormalImageURLRefetchRequest(
                        index: index,
                        pageNum: pageNum,
                        galleryURL: galleryURL,
                        thumbnailURL: thumbnailURL,
                        storedImageURL: imageURL
                    )
                    .response()
                    await send(.refetchNormalImageURLsDone(index, response))
                }
                .cancellable(id: CancelID.refetchNormalImageURLs)

            case .refetchNormalImageURLsDone(let index, let result):
                switch result {
                case .success(let (imageURLs, response)):
                    var effects = [Effect<Action>]()
                    if let response = response {
                        effects.append(.run(operation: { _ in cookieClient.setSkipServer(response: response) }))
                    }
                    guard !imageURLs.isEmpty else {
                        state.imageURLLoadingStates[index] = .failed(.notFound)
                        return effects.isEmpty ? .none : .merge(effects)
                    }
                    state.imageURLLoadingStates[index] = .idle
                    state.updateImageURLs(imageURLs, [:])
                    effects.append(.send(.syncImageURLs(imageURLs, [:])))
                    return .merge(effects)
                case .failure(let error):
                    state.imageURLLoadingStates[index] = .failed(error)
                }
                return .none

            case .fetchMPVKeys(let index, let mpvURL):
                return .run { send in
                    let response = await MPVKeysRequest(mpvURL: mpvURL).response()
                    await send(.fetchMPVKeysDone(index, response))
                }
                .cancellable(id: CancelID.fetchMPVKeys)

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
                            .send(.fetchMPVImageURL($0, false))
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
                return .run { send in
                    let response = await GalleryMPVImageURLRequest(
                        gid: gidInteger,
                        index: index,
                        mpvKey: mpvKey,
                        mpvImageKey: mpvImageKey,
                        skipServerIdentifier: skipServerIdentifier
                    )
                    .response()
                    await send(.fetchMPVImageURLDone(index, response))
                }
                .cancellable(id: CancelID.fetchMPVImageURL)

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
                    return .send(.syncImageURLs(imageURLs, originalImageURLs))
                case .failure(let error):
                    state.imageURLLoadingStates[index] = .failed(error)
                }
                return .none
            }
        }
        .haptics(
            unwrapping: \.route,
            case: \.readingSetting,
            hapticsClient: hapticsClient
        )
        .haptics(
            unwrapping: \.route,
            case: \.share,
            hapticsClient: hapticsClient
        )
    }
}
