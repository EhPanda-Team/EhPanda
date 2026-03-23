//
//  ReadingReducer.swift
//  EhPanda
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
        case observeDownloads
        case loadLocalPageURLs
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
        var contentSource: ReadingContentSource = .remote
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
        var localPageURLs = [Int: URL]()
        var localPageRequestID = UUID()

        var thumbnailURLs = [Int: URL]()
        var imageURLs = [Int: URL]()
        var originalImageURLs = [Int: URL]()

        var mpvKey: String?
        var mpvImageKeys = [Int: String]()
        var mpvSkipServerIdentifiers = [Int: String]()

        var showsPanel = false
        var showsSliderPreview = false

        init(contentSource: ReadingContentSource = .remote) {
            self.contentSource = contentSource
        }

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
        case observeDownloads(String)
        case observeDownloadsDone([DownloadedGallery])
        case loadLocalPageURLs(String)
        case loadLocalPageURLsDone(UUID, [Int: URL])

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
        case captureCachedPage(Int)
    }

    @Dependency(\.appDelegateClient) private var appDelegateClient
    @Dependency(\.clipboardClient) private var clipboardClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.downloadClient) private var downloadClient
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
                    .send(.fetchDatabaseInfos(gid)),
                    .send(.observeDownloads(gid)),
                    .send(.loadLocalPageURLs(gid))
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
                guard state.contentSource == .remote,
                      state.gallery.id.isValidGID,
                      state.localPageURLs[index] == nil
                else {
                    return .none
                }
                return .send(.captureCachedPage(index))

            case .onWebImageFailed(let index):
                state.imageURLLoadingStates[index] = .failed(.webImageFailed)
                return .none

            case .reloadAllWebImages:
                guard state.contentSource == .remote else {
                    if case .local(let download, let manifest) = state.contentSource {
                        applyLocalSource(
                            state: &state,
                            download: download,
                            manifest: manifest
                        )
                    }
                    return .none
                }
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
                guard state.contentSource == .remote else { return .none }
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
                guard state.contentSource == .remote else { return .none }
                return .run { [state] _ in
                    await databaseClient.updatePreviewURLs(gid: state.gallery.id, previewURLs: previewURLs)
                }

            case .syncThumbnailURLs(let thumbnailURLs):
                guard state.contentSource == .remote else { return .none }
                return .run { [state] _ in
                    await databaseClient.updateThumbnailURLs(gid: state.gallery.id, thumbnailURLs: thumbnailURLs)
                }

            case .syncImageURLs(let imageURLs, let originalImageURLs):
                guard state.contentSource == .remote else { return .none }
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
                if case .local(let download, let manifest) = state.contentSource {
                    applyLocalSource(
                        state: &state,
                        download: download,
                        manifest: manifest
                    )
                } else {
                    guard let gallery = databaseClient.fetchGallery(gid: gid) else { return .none }
                    state.gallery = gallery
                    state.galleryDetail = databaseClient.fetchGalleryDetail(gid: state.gallery.id)
                }
                return .run { [state] send in
                    guard let dbState = await databaseClient.fetchGalleryState(gid: state.gallery.id) else { return }
                    await send(.fetchDatabaseInfosDone(dbState))
                }
                .cancellable(id: CancelID.fetchDatabaseInfos)

            case .fetchDatabaseInfosDone(let galleryState):
                if state.contentSource == .remote {
                    if let previewConfig = galleryState.previewConfig {
                        state.previewConfig = previewConfig
                    }
                    state.previewURLs = galleryState.previewURLs
                    state.imageURLs = galleryState.imageURLs
                    state.thumbnailURLs = galleryState.thumbnailURLs
                    state.originalImageURLs = galleryState.originalImageURLs
                }
                state.readingProgress = galleryState.readingProgress
                state.databaseLoadingState = .idle
                return .none

            case .observeDownloads(let gid):
                guard gid.isValidGID else { return .none }
                return .run { send in
                    var previousRelevantDownloads = [DownloadedGallery]()
                    var hadRelevantDownloads = false
                    for await downloads in downloadClient.observeDownloads() {
                        let relevantDownloads = downloads.filter { $0.gid == gid }
                        let hasRelevantDownloads = !relevantDownloads.isEmpty
                        guard hasRelevantDownloads || hadRelevantDownloads else { continue }
                        if relevantDownloads == previousRelevantDownloads {
                            hadRelevantDownloads = hasRelevantDownloads
                            continue
                        }
                        previousRelevantDownloads = relevantDownloads
                        hadRelevantDownloads = hasRelevantDownloads
                        await send(.observeDownloadsDone(relevantDownloads))
                    }
                }
                .cancellable(id: CancelID.observeDownloads, cancelInFlight: true)

            case .observeDownloadsDone:
                guard state.gallery.id.isValidGID else { return .none }
                return .send(.loadLocalPageURLs(state.gallery.id))

            case .loadLocalPageURLs(let gid):
                guard gid.isValidGID else {
                    state.localPageRequestID = UUID()
                    state.localPageURLs = .init()
                    return .none
                }
                let requestID = UUID()
                state.localPageRequestID = requestID
                return .run { send in
                    let localPageURLs: [Int: URL]
                    switch await downloadClient.loadLocalPageURLs(gid) {
                    case .success(let pageURLs):
                        localPageURLs = pageURLs
                    case .failure:
                        localPageURLs = [:]
                    }
                    await send(.loadLocalPageURLsDone(requestID, localPageURLs))
                }
                .cancellable(id: CancelID.loadLocalPageURLs, cancelInFlight: true)

            case .loadLocalPageURLsDone(let requestID, let localPageURLs):
                guard state.localPageRequestID == requestID else { return .none }
                if case .local = state.contentSource,
                   localPageURLs.isEmpty
                {
                    state.contentSource = .remote
                    state.previewURLs = .init()
                    state.thumbnailURLs = .init()
                    state.imageURLs = .init()
                    state.originalImageURLs = .init()
                    state.forceRefreshID = .init()
                }
                state.localPageURLs = localPageURLs
                return .none

            case .fetchPreviewURLs(let index):
                guard state.contentSource == .remote else {
                    state.previewLoadingStates[index] = .idle
                    return .none
                }
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
                guard state.contentSource == .remote else {
                    state.imageURLLoadingStates[index] = .idle
                    return .none
                }
                guard state.localPageURLs[index] == nil else {
                    state.imageURLLoadingStates[index] = .idle
                    return .none
                }
                if state.mpvKey != nil {
                    return .send(.fetchMPVImageURL(index, false))
                } else {
                    return .send(.fetchThumbnailURLs(index))
                }

            case .refetchImageURLs(let index):
                guard state.contentSource == .remote else {
                    state.imageURLLoadingStates[index] = .idle
                    return .none
                }
                guard state.localPageURLs[index] == nil else {
                    state.imageURLLoadingStates[index] = .idle
                    return .none
                }
                if state.mpvKey != nil {
                    return .send(.fetchMPVImageURL(index, true))
                } else {
                    return .send(.refetchNormalImageURLs(index))
                }

            case .prefetchImages(let index, let prefetchLimit):
                guard state.contentSource == .remote else { return .none }
                func getPrefetchImageURLs(range: ClosedRange<Int>) -> [URL] {
                    (range.lowerBound...range.upperBound).compactMap { index in
                        if let url = state.localPageURLs[index], !url.isFileURL {
                            return url
                        }
                        if let url = state.imageURLs[index] {
                            return url
                        }
                        return nil
                    }
                }
                func getFetchImageURLIndices(range: ClosedRange<Int>) -> [Int] {
                    (range.lowerBound...range.upperBound).compactMap { index in
                        if state.localPageURLs[index] != nil {
                            return nil
                        }
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
                guard state.contentSource == .remote else {
                    state.imageURLLoadingStates[index] = .idle
                    return .none
                }
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
                guard state.contentSource == .remote else {
                    state.imageURLLoadingStates[index] = .idle
                    return .none
                }
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
                guard state.contentSource == .remote else {
                    state.imageURLLoadingStates[index] = .idle
                    return .none
                }
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
                guard state.contentSource == .remote else {
                    state.imageURLLoadingStates[index] = .idle
                    return .none
                }
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
                guard state.contentSource == .remote else {
                    state.imageURLLoadingStates[index] = .idle
                    return .none
                }
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

            case .captureCachedPage(let index):
                guard state.contentSource == .remote,
                      state.gallery.id.isValidGID
                else {
                    return .none
                }
                let gid = state.gallery.id
                let imageURL = state.imageURLs[index]
                return .run { _ in
                    await downloadClient.captureCachedPage(
                        gid,
                        index,
                        imageURL
                    )
                }
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

private extension ReadingReducer {
    func applyLocalSource(
        state: inout State,
        download: DownloadedGallery,
        manifest: DownloadManifest
    ) {
        guard let folderURL = download.folderURL else { return }

        state.gallery = download.gallery
        state.galleryDetail = GalleryDetail(
            gid: download.gid,
            title: download.title,
            jpnTitle: download.jpnTitle,
            isFavorited: false,
            visibility: .yes,
            rating: download.rating,
            userRating: 0,
            ratingCount: 0,
            category: download.category,
            language: manifest.language,
            uploader: download.uploader ?? "",
            postedDate: download.postedDate,
            coverURL: download.coverURL,
            favoritedCount: 0,
            pageCount: download.pageCount,
            sizeCount: 0,
            sizeType: "",
            torrentCount: 0
        )
        let imageURLs = manifest.imageURLs(folderURL: folderURL)
        state.localPageURLs = imageURLs
        state.previewConfig = .normal(rows: 4)
        state.previewURLs = imageURLs
        state.thumbnailURLs = imageURLs
        state.imageURLs = imageURLs
        state.originalImageURLs = imageURLs
        state.mpvKey = nil
        state.mpvImageKeys = .init()
        state.mpvSkipServerIdentifiers = .init()
        state.imageURLLoadingStates = .init()
        state.previewLoadingStates = .init()
        state.databaseLoadingState = .idle
    }
}
