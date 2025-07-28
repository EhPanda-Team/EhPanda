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
    
    // MARK: - Image Action
    enum ImageAction {
        case copy(Bool)
        case save(Bool)
        case share(Bool)
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
        case fetchImage(ImageAction, URL)
        case fetchImageDone(ImageAction, Result<UIImage, Error>)
        
        // MARK: - Data Synchronization
        case syncReadingProgress(Int)
        case syncPreviewURLs([Int: URL])
        case syncThumbnailURLs([Int: URL])
        case syncImageURLs([Int: URL], [Int: URL])
        
        // MARK: - Database Operations
        case fetchDatabaseInfos(String)
        case fetchDatabaseInfosDone(GalleryState)
        
        // MARK: - Preview Operations
        case fetchPreviewURLs(Int)
        case fetchPreviewURLsDone(Int, Result<[Int: URL], AppError>)
        
        // MARK: - Image URL Operations
        case fetchImageURLs(Int)
        case refetchImageURLs(Int)
        case prefetchImages(Int, Int)
        
        // MARK: - Thumbnail Operations
        case fetchThumbnailURLs(Int)
        case fetchThumbnailURLsDone(Int, Result<[Int: URL], AppError>)
        
        // MARK: - Normal Image Operations
        case fetchNormalImageURLs(Int, [Int: URL])
        case fetchNormalImageURLsDone(Int, Result<([Int: URL], [Int: URL]), AppError>)
        case refetchNormalImageURLs(Int)
        case refetchNormalImageURLsDone(Int, Result<([Int: URL], HTTPURLResponse?), AppError>)
        
        // MARK: - MPV Operations
        case fetchMPVKeys(Int, URL)
        case fetchMPVKeysDone(Int, Result<(String, [Int: String]), AppError>)
        case fetchMPVImageURL(Int, Bool)
        case fetchMPVImageURLDone(Int, Result<(URL, URL?, String), AppError>)
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
                return handleSetNavigation(&state, route: route)
                
            case .toggleShowsPanel:
                return handleToggleShowsPanel(&state)
                
            case .onPerformDismiss:
                return handlePerformDismiss()
                
            case .onAppear(let gid, let enablesLandscape):
                return handleOnAppear(&state, gid: gid, enablesLandscape: enablesLandscape)
                
            case .teardown:
                return handleTeardown(&state)
                
            // MARK: - Orientation Actions
            case .setOrientationPortrait(let isPortrait):
                return handleSetOrientationPortrait(isPortrait: isPortrait)
                
            // MARK: - Web Image Actions
            case .onWebImageRetry(let index):
                return handleWebImageRetry(&state, index: index)
                
            case .onWebImageSucceeded(let index):
                return handleWebImageSucceeded(&state, index: index)
                
            case .onWebImageFailed(let index):
                return handleWebImageFailed(&state, index: index)
                
            case .reloadAllWebImages:
                return handleReloadAllWebImages(&state)
                
            case .retryAllFailedWebImages:
                return handleRetryAllFailedWebImages(&state)
                
            // MARK: - Image Actions
            case .copyImage(let imageURL):
                return handleCopyImage(imageURL: imageURL)
                
            case .saveImage(let imageURL):
                return handleSaveImage(imageURL: imageURL)
                
            case .saveImageDone(let isSucceeded):
                return handleSaveImageDone(&state, isSucceeded: isSucceeded)
                
            case .shareImage(let imageURL):
                return handleShareImage(imageURL: imageURL)
                
            case .fetchImage(let action, let imageURL):
                return handleFetchImage(action: action, imageURL: imageURL)
                
            case .fetchImageDone(let action, let result):
                return handleFetchImageDone(&state, action: action, result: result)
                
            // MARK: - Synchronization Actions
            case .syncReadingProgress(let progress):
                return handleSyncReadingProgress(state: state, progress: progress)
                
            case .syncPreviewURLs(let previewURLs):
                return handleSyncPreviewURLs(state: state, previewURLs: previewURLs)
                
            case .syncThumbnailURLs(let thumbnailURLs):
                return handleSyncThumbnailURLs(state: state, thumbnailURLs: thumbnailURLs)
                
            case .syncImageURLs(let imageURLs, let originalImageURLs):
                return handleSyncImageURLs(
                    state: state, 
                    imageURLs: imageURLs, 
                    originalImageURLs: originalImageURLs
                )
                
            // MARK: - Database Actions
            case .fetchDatabaseInfos(let gid):
                return handleFetchDatabaseInfos(&state, gid: gid)
                
            case .fetchDatabaseInfosDone(let galleryState):
                return handleFetchDatabaseInfosDone(&state, galleryState: galleryState)
                
            // MARK: - Preview Actions
            case .fetchPreviewURLs(let index):
                return handleFetchPreviewURLs(&state, index: index)
                
            case .fetchPreviewURLsDone(let index, let result):
                return handleFetchPreviewURLsDone(&state, index: index, result: result)
                
            // MARK: - Image URL Actions
            case .fetchImageURLs(let index):
                return handleFetchImageURLs(&state, index: index)
                
            case .refetchImageURLs(let index):
                return handleRefetchImageURLs(&state, index: index)
                
            case .prefetchImages(let index, let prefetchLimit):
                return handlePrefetchImages(&state, index: index, prefetchLimit: prefetchLimit)
                
            // MARK: - Thumbnail Actions
            case .fetchThumbnailURLs(let index):
                return handleFetchThumbnailURLs(&state, index: index)
                
            case .fetchThumbnailURLsDone(let index, let result):
                return handleFetchThumbnailURLsDone(&state, index: index, result: result)
                
            // MARK: - Normal Image Actions
            case .fetchNormalImageURLs(let index, let thumbnailURLs):
                return handleFetchNormalImageURLs(index: index, thumbnailURLs: thumbnailURLs)
                
            case .fetchNormalImageURLsDone(let index, let result):
                return handleFetchNormalImageURLsDone(&state, index: index, result: result)
                
            case .refetchNormalImageURLs(let index):
                return handleRefetchNormalImageURLs(&state, index: index)
                
            case .refetchNormalImageURLsDone(let index, let result):
                return handleRefetchNormalImageURLsDone(&state, index: index, result: result)
                
            // MARK: - MPV Actions
            case .fetchMPVKeys(let index, let mpvURL):
                return handleFetchMPVKeys(index: index, mpvURL: mpvURL)
                
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
    
    /// Basic Action Handlers
    func handleSetNavigation(_ state: inout State, route: Route?) -> Effect<Action> {
        state.route = route
        return .none
    }
    
    func handleToggleShowsPanel(_ state: inout State) -> Effect<Action> {
        state.showsPanel.toggle()
        return .none
    }
    
    func handlePerformDismiss() -> Effect<Action> {
        return .run(operation: { _ in 
            hapticsClient.generateFeedback(.light) 
        })
    }
    
    func handleOnAppear(_ state: inout State, gid: String, enablesLandscape: Bool) -> Effect<Action> {
        var effects: [Effect<Action>] = [
            .send(.fetchDatabaseInfos(gid))
        ]
        if enablesLandscape {
            effects.append(.send(.setOrientationPortrait(false)))
        }
        return .merge(effects)
    }
    
    func handleTeardown(_ state: inout State) -> Effect<Action> {
        var effects: [Effect<Action>] = [
            .merge(CancelID.allCases.map(Effect.cancel(id:)))
        ]
        if !deviceClient.isPad() {
            effects.append(.send(.setOrientationPortrait(true)))
        }
        return .merge(effects)
    }
    
    /// Orientation Handlers
    func handleSetOrientationPortrait(isPortrait: Bool) -> Effect<Action> {
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
    }
    
    /// Web Image Handlers
    func handleWebImageRetry(_ state: inout State, index: Int) -> Effect<Action> {
        state.imageURLLoadingStates[index] = .idle
        return .none
    }
    
    func handleWebImageSucceeded(_ state: inout State, index: Int) -> Effect<Action> {
        state.imageURLLoadingStates[index] = .idle
        state.webImageLoadSuccessIndices.insert(index)
        return .none
    }
    
    func handleWebImageFailed(_ state: inout State, index: Int) -> Effect<Action> {
        state.imageURLLoadingStates[index] = .failed(.webImageFailed)
        return .none
    }
    
    func handleReloadAllWebImages(_ state: inout State) -> Effect<Action> {
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
    }
    
    func handleRetryAllFailedWebImages(_ state: inout State) -> Effect<Action> {
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
    }
    
    /// Image Action Handlers
    func handleCopyImage(imageURL: URL) -> Effect<Action> {
        return .send(.fetchImage(.copy(imageURL.isGIF), imageURL))
    }
    
    func handleSaveImage(imageURL: URL) -> Effect<Action> {
        return .send(.fetchImage(.save(imageURL.isGIF), imageURL))
    }
    
    func handleSaveImageDone(_ state: inout State, isSucceeded: Bool) -> Effect<Action> {
        state.hudConfig = isSucceeded ? .savedToPhotoLibrary : .error
        return .send(.setNavigation(.hud))
    }
    
    func handleShareImage(imageURL: URL) -> Effect<Action> {
        return .send(.fetchImage(.share(imageURL.isGIF), imageURL))
    }
    
    func handleFetchImage(action: ImageAction, imageURL: URL) -> Effect<Action> {
        return .run { send in
            let result = await imageClient.fetchImage(url: imageURL)
            await send(.fetchImageDone(action, result))
        }
        .cancellable(id: CancelID.fetchImage)
    }
    
    func handleFetchImageDone(
        _ state: inout State, 
        action: ImageAction, 
        result: Result<UIImage, Error>
    ) -> Effect<Action> {
        switch result {
        case .success(let image):
            return handleSuccessfulImageFetch(state: &state, action: action, image: image)
        case .failure:
            state.hudConfig = .error
            return .send(.setNavigation(.hud))
        }
    }
    
    private func handleSuccessfulImageFetch(
        state: inout State, 
        action: ImageAction, 
        image: UIImage
    ) -> Effect<Action> {
        switch action {
        case .copy(let isAnimated):
            state.hudConfig = .copiedToClipboardSucceeded
            return .merge(
                .send(.setNavigation(.hud)),
                .run(operation: { _ in 
                    clipboardClient.saveImage(image, isAnimated) 
                })
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
    }
    
    /// Synchronization Handlers
    func handleSyncReadingProgress(state: State, progress: Int) -> Effect<Action> {
        return .run { _ in
            await databaseClient.updateReadingProgress(
                gid: state.gallery.id, 
                progress: progress
            )
        }
    }
    
    func handleSyncPreviewURLs(state: State, previewURLs: [Int: URL]) -> Effect<Action> {
        return .run { _ in
            await databaseClient.updatePreviewURLs(
                gid: state.gallery.id, 
                previewURLs: previewURLs
            )
        }
    }
    
    func handleSyncThumbnailURLs(state: State, thumbnailURLs: [Int: URL]) -> Effect<Action> {
        return .run { _ in
            await databaseClient.updateThumbnailURLs(
                gid: state.gallery.id, 
                thumbnailURLs: thumbnailURLs
            )
        }
    }
    
    func handleSyncImageURLs(
        state: State, 
        imageURLs: [Int: URL], 
        originalImageURLs: [Int: URL]
    ) -> Effect<Action> {
        return .run { _ in
            await databaseClient.updateImageURLs(
                gid: state.gallery.id,
                imageURLs: imageURLs,
                originalImageURLs: originalImageURLs
            )
        }
    }
    
    /// Database Handlers
    func handleFetchDatabaseInfos(_ state: inout State, gid: String) -> Effect<Action> {
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
    }
    
    func handleFetchDatabaseInfosDone(
        _ state: inout State, 
        galleryState: GalleryState
    ) -> Effect<Action> {
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
    }
    
    /// Preview Handlers
    func handleFetchPreviewURLs(_ state: inout State, index: Int) -> Effect<Action> {
        guard state.previewLoadingStates[index] != .loading,
              let galleryURL = state.gallery.galleryURL
        else { 
            return .none 
        }
        
        state.previewLoadingStates[index] = .loading
        let pageNum = state.previewConfig.pageNumber(index: index)
        
        return .run { send in
            let response = await GalleryPreviewURLsRequest(
                galleryURL: galleryURL, 
                pageNum: pageNum
            ).response()
            await send(.fetchPreviewURLsDone(index, response))
        }
        .cancellable(id: CancelID.fetchPreviewURLs)
    }
    
    func handleFetchPreviewURLsDone(
        _ state: inout State, 
        index: Int, 
        result: Result<[Int: URL], AppError>
    ) -> Effect<Action> {
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
            return .none
        }
    }
    
    /// Image URL Handlers
    func handleFetchImageURLs(_ state: inout State, index: Int) -> Effect<Action> {
        if state.mpvKey != nil {
            return .send(.fetchMPVImageURL(index, false))
        } else {
            return .send(.fetchThumbnailURLs(index))
        }
    }
    
    func handleRefetchImageURLs(_ state: inout State, index: Int) -> Effect<Action> {
        if state.mpvKey != nil {
            return .send(.fetchMPVImageURL(index, true))
        } else {
            return .send(.refetchNormalImageURLs(index))
        }
    }
    
    func handlePrefetchImages(
        _ state: inout State, 
        index: Int, 
        prefetchLimit: Int
    ) -> Effect<Action> {
        let prefetchHelper = PrefetchHelper(state: state, imageClient: imageClient)
        return prefetchHelper.createPrefetchEffects(
            currentIndex: index, 
            prefetchLimit: prefetchLimit
        )
    }
    
    /// Thumbnail Handlers
    func handleFetchThumbnailURLs(_ state: inout State, index: Int) -> Effect<Action> {
        guard state.imageURLLoadingStates[index] != .loading,
              let galleryURL = state.gallery.galleryURL
        else { 
            return .none 
        }
        
        state.previewConfig.batchRange(index: index).forEach {
            state.imageURLLoadingStates[$0] = .loading
        }
        
        let pageNum = state.previewConfig.pageNumber(index: index)
        
        return .run { send in
            let response = await ThumbnailURLsRequest(
                galleryURL: galleryURL, 
                pageNum: pageNum
            ).response()
            await send(.fetchThumbnailURLsDone(index, response))
        }
        .cancellable(id: CancelID.fetchThumbnailURLs)
    }
    
    func handleFetchThumbnailURLsDone(
        _ state: inout State, 
        index: Int, 
        result: Result<[Int: URL], AppError>
    ) -> Effect<Action> {
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
            return .none
        }
    }
    
    /// Normal Image Handlers
    func handleFetchNormalImageURLs(
        index: Int, 
        thumbnailURLs: [Int: URL]
    ) -> Effect<Action> {
        return .run { send in
            let response = await GalleryNormalImageURLsRequest(
                thumbnailURLs: thumbnailURLs
            ).response()
            await send(.fetchNormalImageURLsDone(index, response))
        }
        .cancellable(id: CancelID.fetchNormalImageURLs)
    }
    
    func handleFetchNormalImageURLsDone(
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
    
    func handleRefetchNormalImageURLs(_ state: inout State, index: Int) -> Effect<Action> {
        guard state.imageURLLoadingStates[index] != .loading,
              let galleryURL = state.gallery.galleryURL,
              let imageURL = state.imageURLs[index]
        else { 
            return .none 
        }
        
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
            await send(.refetchNormalImageURLsDone(index, response))
        }
        .cancellable(id: CancelID.refetchNormalImageURLs)
    }
    
    func handleRefetchNormalImageURLsDone(
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
    
    /// MPV Handlers
    func handleFetchMPVKeys(index: Int, mpvURL: URL) -> Effect<Action> {
        return .run { send in
            let response = await MPVKeysRequest(mpvURL: mpvURL).response()
            await send(.fetchMPVKeysDone(index, response))
        }
        .cancellable(id: CancelID.fetchMPVKeys)
    }
    
    func handleFetchMPVKeysDone(
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
    
    func handleFetchMPVImageURL(
        _ state: inout State, 
        index: Int, 
        isRefresh: Bool
    ) -> Effect<Action> {
        guard let gidInteger = Int(state.gallery.id), 
              let mpvKey = state.mpvKey,
              let mpvImageKey = state.mpvImageKeys[index],
              state.imageURLLoadingStates[index] != .loading
        else { 
            return .none 
        }
        
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
    
    func handleFetchMPVImageURLDone(
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
    
    func createPrefetchEffects(currentIndex: Int, prefetchLimit: Int) -> Effect<ReadingReducer.Action> {
        let (prefetchURLs, fetchIndices) = calculatePrefetchData(
            currentIndex: currentIndex, 
            prefetchLimit: prefetchLimit
        )
        
        var effects = fetchIndices.map { index in
            Effect<ReadingReducer.Action>.send(.fetchImageURLs(index))
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