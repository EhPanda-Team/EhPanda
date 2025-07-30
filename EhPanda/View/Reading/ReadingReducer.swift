//
//  ReadingReducer.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/22.
//  Refactored for improved maintainability and modularity by zackie on 2025-07-28.
//

import SwiftUI
import TTProgressHUD
import ComposableArchitecture

// MARK: - Reading Reducer
@Reducer
struct ReadingReducer {
    
    // MARK: - Route
    @CasePathable
    enum Route: Equatable {
        case hud
        case share(IdentifiableBox<ShareItem>)
        case readingSetting(EquatableVoid = .init())
    }
    
    // MARK: - Share Item
    enum ShareItem: Equatable {
        case data(Data)
        case image(UIImage)
        
        var associatedValue: Any {
            switch self {
            case .data(let data): return data
            case .image(let image): return image
            }
        }
    }
    
    // MARK: - Cancel IDs
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
    
    // MARK: - State
    @ObservableState
    struct State: Equatable {
        // MARK: - Navigation & UI
        var route: Route?
        var showsPanel = false
        var showsSliderPreview = false
        var hudConfig: TTProgressHUDConfig = .loading
        var forceRefreshID: UUID = .init()
        
        // MARK: - Gallery Data
        var gallery: Gallery = .empty
        var galleryDetail: GalleryDetail?
        var readingProgress: Int = .zero
        
        // MARK: - Loading States
        var webImageLoadSuccessIndices = Set<Int>()
        var imageURLLoadingStates = [Int: LoadingState]()
        var previewLoadingStates = [Int: LoadingState]()
        var databaseLoadingState: LoadingState = .loading
        
        // MARK: - Preview Configuration
        var previewConfig: PreviewConfig = .normal(rows: 4)
        
        // MARK: - URL Storage
        var previewURLs = [Int: URL]()
        var thumbnailURLs = [Int: URL]()
        var imageURLs = [Int: URL]()
        var originalImageURLs = [Int: URL]()
        
        // MARK: - MPV Support
        var mpvKey: String?
        var mpvImageKeys = [Int: String]()
        var mpvSkipServerIdentifiers = [Int: String]()
    }
    
    // MARK: - Action
    enum Action: BindableAction {
        // MARK: - Binding & Navigation
        case binding(BindingAction<State>)
        case setNavigation(Route?)
        case toggleShowsPanel
        case onPerformDismiss
        case onAppear(String, Bool)
        case teardown
        
        // MARK: - Orientation
        case setOrientationPortrait(Bool)
        
        // MARK: - Web Image Actions
        case onWebImageRetry(Int)
        case onWebImageSucceeded(Int)
        case onWebImageFailed(Int)
        case reloadAllWebImages
        case retryAllFailedWebImages
        
        // MARK: - Image Actions
        case copyImage(URL)
        case saveImage(URL)
        case saveImageDone(Bool)
        case shareImage(URL)
        case fetchImage(URL, ImageOperation)
        case fetchImageDone(ImageOperation, Result<UIImage, Error>)
        
        // MARK: - Data Synchronization
        case syncReadingProgress(Int)
        case syncURLs(URLType, [Int: URL])
        case syncImageURLs([Int: URL], [Int: URL])
        
        // MARK: - Database Operations
        case fetchDatabaseInfos(String)
        case fetchDatabaseInfosDone(GalleryState)
        
        // MARK: - URL Fetch Operations
        case fetchURLs(URLType, Int)
        case fetchURLsDone(URLType, Int, Result<[Int: URL], AppError>)
        case fetchNormalImageURLs(Int, [Int: URL])
        case fetchNormalImageURLsDone(Int, Result<([Int: URL], [Int: URL]), AppError>)
        case refetchImageURLs(Int)
        case refetchImageURLsDone(Int, Result<([Int: URL], HTTPURLResponse?), AppError>)
        case prefetchImages(Int, Int)
        
        // MARK: - MPV Operations
        case fetchMPVKeys(Int, URL)
        case fetchMPVKeysDone(Int, Result<(String, [Int: String]), AppError>)
        case fetchMPVImageURL(Int, Bool)
        case fetchMPVImageURLDone(Int, Result<(URL, URL?, String), AppError>)
    }
    
    // MARK: - Supporting Types
    enum ImageOperation: Equatable {
        case copy
        case save
        case share
    }
    
    enum URLType: Equatable {
        case preview
        case thumbnail
        case normal
    }
    
    // MARK: - Dependencies
    @Dependency(\.appDelegateClient) private var appDelegateClient
    @Dependency(\.clipboardClient) private var clipboardClient
    @Dependency(\.databaseClient) private var databaseClient
    @Dependency(\.hapticsClient) private var hapticsClient
    @Dependency(\.cookieClient) private var cookieClient
    @Dependency(\.deviceClient) private var deviceClient
    @Dependency(\.imageClient) private var imageClient
    @Dependency(\.urlClient) private var urlClient
    
    // MARK: - Body
    var body: some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.showsSliderPreview) { _, _ in
                Reduce({ _, _ in 
                    .run(operation: { _ in 
                        hapticsClient.generateFeedback(.soft) 
                    }) 
                })
            }
        
        Reduce { state, action in
            switch action {
            // MARK: - Basic Actions
            case .binding:
                return .none
                
            case .setNavigation(let route):
                state.route = route
                return .none
                
            case .toggleShowsPanel:
                state.showsPanel.toggle()
                return .none
                
            case .onPerformDismiss:
                return .run(operation: { _ in 
                    hapticsClient.generateFeedback(.light) 
                })
                
            case .onAppear(let gid, let enablesLandscape):
                var effects: [Effect<Action>] = [
                    .send(.fetchDatabaseInfos(gid))
                ]
                if enablesLandscape {
                    effects.append(.send(.setOrientationPortrait(false)))
                }
                return .merge(effects)
                
            case .teardown:
                var effects: [Effect<Action>] = [
                    .merge(CancelID.allCases.map(Effect.cancel(id:)))
                ]
                if !deviceClient.isPad() {
                    effects.append(.send(.setOrientationPortrait(true)))
                }
                return .merge(effects)
                
            // MARK: - Orientation Actions
            case .setOrientationPortrait(let isPortrait):
                var effects = [Effect<Action>]()
                if isPortrait {
                    effects.append(.run(operation: { _ in 
                        appDelegateClient.setPortraitOrientationMask() 
                    }))
                    effects.append(.run(operation: { _ in 
                        await appDelegateClient.setPortraitOrientation() 
                    }))
                } else {
                    effects.append(.run(operation: { _ in 
                        appDelegateClient.setAllOrientationMask() 
                    }))
                }
                return .merge(effects)
                
            // MARK: - Web Image Actions
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
                
                return .run { [galleryId = state.gallery.id] _ in
                    await databaseClient.removeImageURLs(gid: galleryId)
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
                
            // MARK: - Image Actions
            case .copyImage(let imageURL):
                return .send(.fetchImage(imageURL, .copy))
                
            case .saveImage(let imageURL):
                return .send(.fetchImage(imageURL, .save))
                
            case .shareImage(let imageURL):
                return .send(.fetchImage(imageURL, .share))
                
            case .saveImageDone(let isSucceeded):
                state.hudConfig = isSucceeded ? .savedToPhotoLibrary : .error
                return .send(.setNavigation(.hud))
                
            case .fetchImage(let imageURL, let operation):
                return .run { send in
                    let result = await imageClient.fetchImage(url: imageURL)
                    await send(.fetchImageDone(operation, result))
                }
                .cancellable(id: CancelID.fetchImage)
                
            case .fetchImageDone(let operation, let result):
                switch result {
                case .success(let image):
                    return handleSuccessfulImageFetch(state: &state, operation: operation, image: image)
                case .failure:
                    state.hudConfig = .error
                    return .send(.setNavigation(.hud))
                }
                
            // MARK: - Synchronization Actions
            case .syncReadingProgress(let progress):
                return .run { [galleryId = state.gallery.id] _ in
                    await databaseClient.updateReadingProgress(
                        gid: galleryId, 
                        progress: progress
                    )
                }
                
            case .syncURLs(let urlType, let urls):
                return .run { [galleryId = state.gallery.id] _ in
                    switch urlType {
                    case .preview:
                        await databaseClient.updatePreviewURLs(gid: galleryId, previewURLs: urls)
                    case .thumbnail:
                        await databaseClient.updateThumbnailURLs(gid: galleryId, thumbnailURLs: urls)
                    case .normal:
                        break // Handled by syncImageURLs
                    }
                }
                
            case .syncImageURLs(let imageURLs, let originalImageURLs):
                return .run { [galleryId = state.gallery.id] _ in
                    await databaseClient.updateImageURLs(
                        gid: galleryId,
                        imageURLs: imageURLs,
                        originalImageURLs: originalImageURLs
                    )
                }
                
            // MARK: - Database Actions
            case .fetchDatabaseInfos(let gid):
                guard let gallery = databaseClient.fetchGallery(gid: gid) else { 
                    return .none 
                }
                
                state.gallery = gallery
                state.galleryDetail = databaseClient.fetchGalleryDetail(gid: state.gallery.id)
                
                return .run { [galleryId = state.gallery.id] send in
                    guard let dbState = await databaseClient.fetchGalleryState(gid: galleryId) else { 
                        return 
                    }
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
                state.originalImageURLs = galleryState.originalImageURLs
                state.readingProgress = galleryState.readingProgress
                state.databaseLoadingState = .idle
                return .none
                
            // MARK: - URL Fetch Actions
            case .fetchURLs(let urlType, let index):
                return handleFetchURLs(&state, urlType: urlType, index: index)
                
            case .fetchURLsDone(let urlType, let index, let result):
                return handleFetchURLsDone(&state, urlType: urlType, index: index, result: result)
                
            case .refetchImageURLs(let index):
                if state.mpvKey != nil {
                    return .send(.fetchMPVImageURL(index, true))
                } else {
                    return handleRefetchNormalImageURLs(&state, index: index)
                }
                
            case .refetchImageURLsDone(let index, let result):
                return handleRefetchImageURLsDone(&state, index: index, result: result)
                
            case .fetchNormalImageURLs(let index, let thumbnailURLs):
                return fetchNormalImageURLs(index: index, thumbnailURLs: thumbnailURLs)
                
            case .fetchNormalImageURLsDone(let index, let result):
                return handleFetchNormalImageURLsDone(&state, index: index, result: result)
                
            case .prefetchImages(let index, let prefetchLimit):
                 let prefetchHelper = PrefetchHelper(state: state, imageClient: imageClient)
                 return prefetchHelper.createPrefetchEffects(
                     currentIndex: index, 
                     prefetchLimit: prefetchLimit
                 )
                
            // MARK: - MPV Actions
            case .fetchMPVKeys(let index, let mpvURL):
                return .run { send in
                    let response = await MPVKeysRequest(mpvURL: mpvURL).response()
                    await send(.fetchMPVKeysDone(index, response))
                }
                .cancellable(id: CancelID.fetchMPVKeys)
                
            case .fetchMPVKeysDone(let index, let result):
                return handleFetchMPVKeysDone(&state, index: index, result: result)
                
            case .fetchMPVImageURL(let index, let isRefresh):
                return handleFetchMPVImageURL(&state, index: index, isRefresh: isRefresh)
                
            case .fetchMPVImageURLDone(let index, let result):
                return handleFetchMPVImageURLDone(&state, index: index, result: result)
            }
        }
        .haptics(unwrapping: \.route, case: \.readingSetting, hapticsClient: hapticsClient)
        .haptics(unwrapping: \.route, case: \.share, hapticsClient: hapticsClient)
    }
    
    // MARK: - Handler Methods
    
    private func handleSuccessfulImageFetch(
        state: inout State, 
        operation: ImageOperation, 
        image: UIImage
    ) -> Effect<Action> {
        switch operation {
        case .copy:
            state.hudConfig = .copiedToClipboardSucceeded
            return .merge(
                .send(.setNavigation(.hud)),
                .run(operation: { _ in 
                    clipboardClient.saveImage(image, image.kf.data(format: .GIF) != nil) 
                })
            )
        case .save:
            return .run { send in
                let success = await imageClient.saveImageToPhotoLibrary(image, image.kf.data(format: .GIF) != nil)
                await send(.saveImageDone(success))
            }
        case .share:
            if let data = image.kf.data(format: .GIF) {
                return .send(.setNavigation(.share(.init(value: .data(data)))))
            } else {
                return .send(.setNavigation(.share(.init(value: .image(image)))))
            }
        }
    }
    
    private func handleFetchURLs(_ state: inout State, urlType: URLType, index: Int) -> Effect<Action> {
        switch urlType {
        case .preview:
            guard state.previewLoadingStates[index] != .loading,
                  let galleryURL = state.gallery.galleryURL
            else { return .none }
            
            state.previewLoadingStates[index] = .loading
            let pageNum = state.previewConfig.pageNumber(index: index)
            
            return .run { send in
                let response = await GalleryPreviewURLsRequest(
                    galleryURL: galleryURL, 
                    pageNum: pageNum
                ).response()
                await send(.fetchURLsDone(.preview, index, response))
            }
            .cancellable(id: CancelID.fetchPreviewURLs)
            
        case .thumbnail:
            guard state.imageURLLoadingStates[index] != .loading,
                  let galleryURL = state.gallery.galleryURL
            else { return .none }
            
            state.previewConfig.batchRange(index: index).forEach {
                state.imageURLLoadingStates[$0] = .loading
            }
            
            let pageNum = state.previewConfig.pageNumber(index: index)
            
            return .run { send in
                let response = await ThumbnailURLsRequest(
                    galleryURL: galleryURL, 
                    pageNum: pageNum
                ).response()
                await send(.fetchURLsDone(.thumbnail, index, response))
            }
            .cancellable(id: CancelID.fetchThumbnailURLs)
            
        case .normal:
            if state.mpvKey != nil {
                return .send(.fetchMPVImageURL(index, false))
            } else {
                return .send(.fetchURLs(.thumbnail, index))
            }
        }
    }
    
    private func handleFetchURLsDone(
        _ state: inout State, 
        urlType: URLType, 
        index: Int, 
        result: Result<[Int: URL], AppError>
    ) -> Effect<Action> {
        switch result {
        case .success(let urls):
            guard !urls.isEmpty else {
                switch urlType {
                case .preview:
                    state.previewLoadingStates[index] = .failed(.notFound)
                case .thumbnail, .normal:
                    let batchRange = state.previewConfig.batchRange(index: index)
                    batchRange.forEach {
                        state.imageURLLoadingStates[$0] = .failed(.notFound)
                    }
                }
                return .none
            }
            
            switch urlType {
            case .preview:
                state.previewLoadingStates[index] = .idle
                state.updatePreviewURLs(urls)
                return .send(.syncURLs(.preview, urls))
                
            case .thumbnail:
                let batchRange = state.previewConfig.batchRange(index: index)
                batchRange.forEach {
                    state.imageURLLoadingStates[$0] = .idle
                }
                state.updateThumbnailURLs(urls)
                
                if let url = urls[index], urlClient.checkIfMPVURL(url) {
                    return .send(.fetchMPVKeys(index, url))
                } else {
                    return .merge(
                        .send(.syncURLs(.thumbnail, urls)),
                        .send(.fetchNormalImageURLs(index, urls))
                    )
                }
                
            case .normal:
                return .none // Handled by specific normal image handlers
            }
            
        case .failure(let error):
            switch urlType {
            case .preview:
                state.previewLoadingStates[index] = .failed(error)
            case .thumbnail, .normal:
                let batchRange = state.previewConfig.batchRange(index: index)
                batchRange.forEach {
                    state.imageURLLoadingStates[$0] = .failed(error)
                }
            }
            return .none
        }
    }
    
    private func fetchNormalImageURLs(index: Int, thumbnailURLs: [Int: URL]) -> Effect<Action> {
        return .run { send in
            let response = await GalleryNormalImageURLsRequest(
                thumbnailURLs: thumbnailURLs
            ).response()
            await send(.fetchNormalImageURLsDone(index, response))
        }
        .cancellable(id: CancelID.fetchNormalImageURLs)
    }
    
    private func handleFetchNormalImageURLsDone(
        _ state: inout State, 
        index: Int, 
        result: Result<([Int: URL], [Int: URL]), AppError>
    ) -> Effect<Action> {
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
            return .none
        }
    }
    
    private func handleRefetchNormalImageURLs(_ state: inout State, index: Int) -> Effect<Action> {
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
            ).response()
            await send(.refetchImageURLsDone(index, response))
        }
        .cancellable(id: CancelID.refetchNormalImageURLs)
    }
    
    private func handleRefetchImageURLsDone(
        _ state: inout State, 
        index: Int, 
        result: Result<([Int: URL], HTTPURLResponse?), AppError>
    ) -> Effect<Action> {
        switch result {
        case .success(let (imageURLs, response)):
            var effects = [Effect<Action>]()
            
            if let response = response {
                effects.append(.run(operation: { _ in 
                    cookieClient.setSkipServer(response: response) 
                }))
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
            return .none
        }
    }
    
    private func handleFetchMPVKeysDone(
        _ state: inout State, 
        index: Int, 
        result: Result<(String, [Int: String]), AppError>
    ) -> Effect<Action> {
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
            return .none
        }
    }
    
    private func handleFetchMPVImageURL(
        _ state: inout State, 
        index: Int, 
        isRefresh: Bool
    ) -> Effect<Action> {
        guard let gidInteger = Int(state.gallery.id), 
              let mpvKey = state.mpvKey,
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
            ).response()
            await send(.fetchMPVImageURLDone(index, response))
        }
        .cancellable(id: CancelID.fetchMPVImageURL)
    }
    
    private func handleFetchMPVImageURLDone(
        _ state: inout State, 
        index: Int, 
        result: Result<(URL, URL?, String), AppError>
    ) -> Effect<Action> {
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
            return .none
        }
    }
}

// MARK: - State Extensions
extension ReadingReducer.State {
    /// Updates preview URLs
    mutating func updatePreviewURLs(_ previewURLs: [Int: URL]) {
        guard !previewURLs.isEmpty else { return }
        self.previewURLs = self.previewURLs.merging(previewURLs) { _, new in new }
    }
    
    /// Updates thumbnail URLs
    mutating func updateThumbnailURLs(_ thumbnailURLs: [Int: URL]) {
        guard !thumbnailURLs.isEmpty else { return }
        self.thumbnailURLs = self.thumbnailURLs.merging(thumbnailURLs) { _, new in new }
    }
    
    /// Updates image URLs and original image URLs
    mutating func updateImageURLs(_ imageURLs: [Int: URL], _ originalImageURLs: [Int: URL]) {
        if !imageURLs.isEmpty {
            self.imageURLs = self.imageURLs.merging(imageURLs) { _, new in new }
        }
        if !originalImageURLs.isEmpty {
            self.originalImageURLs = self.originalImageURLs.merging(originalImageURLs) { _, new in new }
        }
    }
    
    /// Gets container data source for the current configuration
    func containerDataSource(setting: Setting, isLandscape: Bool = DeviceUtil.isLandscape) -> [Int] {
        let defaultData = Array(1...gallery.pageCount)
        
        guard isLandscape && 
              setting.enablesDualPageMode && 
              setting.readingDirection != .vertical 
        else { 
            return defaultData 
        }
        
        let data = setting.exceptCover
            ? [1] + Array(stride(from: 2, through: gallery.pageCount, by: 2))
            : Array(stride(from: 1, through: gallery.pageCount, by: 2))
        
        return data
    }
    
    /// Gets image container configurations for dual page mode
    func imageContainerConfigs(
        index: Int, 
        setting: Setting, 
        isLandscape: Bool = DeviceUtil.isLandscape
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
            
        let dualPageConfig = DualPageConfiguration(
            firstIndex: firstIndex,
            secondIndex: secondIndex,
            isFirstAvailable: isValidFirstRange,
            isSecondAvailable: !isFirstPageAndSingle && isValidSecondRange && isDualPage,
            isDualPage: isDualPage
        )
        
        return ImageStackConfig(from: dualPageConfig)
    }
}

// MARK: - Helper Classes

/// Helper class for managing prefetch operations
private struct PrefetchHelper {
    let state: ReadingReducer.State
    let imageClient: ImageClient
    
    init(state: ReadingReducer.State, imageClient: ImageClient) {
        self.state = state
        self.imageClient = imageClient
    }
    
    func createPrefetchEffects(currentIndex: Int, prefetchLimit: Int) -> Effect<ReadingReducer.Action> {
        let (prefetchURLs, fetchIndices) = calculatePrefetchData(
            currentIndex: currentIndex, 
            prefetchLimit: prefetchLimit
        )
        
        var effects = fetchIndices.map { index in
            Effect<ReadingReducer.Action>.send(.fetchURLs(.thumbnail, index))
        }
        
        effects.append(
            .run { _ in
                imageClient.prefetchImages(prefetchURLs)
            }
        )
        
        return .merge(effects)
    }
    
    private func calculatePrefetchData(
        currentIndex: Int, 
        prefetchLimit: Int
    ) -> (urls: [URL], indices: [Int]) {
        var prefetchURLs = [URL]()
        var fetchIndices = [Int]()
        
        // Previous pages
        let previousUpperBound = max(currentIndex - 2, 1)
        let previousLowerBound = max(previousUpperBound - prefetchLimit / 2, 1)
        if previousUpperBound - previousLowerBound > 0 {
            let previousRange = previousLowerBound...previousUpperBound
            prefetchURLs += getURLsForRange(previousRange)
            fetchIndices += getIndicesNeedingFetch(previousRange)
        }
        
        // Next pages
        let nextLowerBound = min(currentIndex + 2, state.gallery.pageCount)
        let nextUpperBound = min(nextLowerBound + prefetchLimit / 2, state.gallery.pageCount)
        if nextUpperBound - nextLowerBound > 0 {
            let nextRange = nextLowerBound...nextUpperBound
            prefetchURLs += getURLsForRange(nextRange)
            fetchIndices += getIndicesNeedingFetch(nextRange)
        }
        
        return (prefetchURLs, fetchIndices)
    }
    
    private func getURLsForRange(_ range: ClosedRange<Int>) -> [URL] {
        return range.compactMap { index in
            state.imageURLs[index]
        }
    }
    
    private func getIndicesNeedingFetch(_ range: ClosedRange<Int>) -> [Int] {
        return range.compactMap { index in
            if state.imageURLs[index] == nil && 
               state.imageURLLoadingStates[index] != .loading {
                return index
            }
            return nil
        }
    }
}