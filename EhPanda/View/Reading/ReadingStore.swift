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
    struct TimerID: Hashable {
        let id = String(describing: ReadingState.TimerID.self)
    }

    @BindableState var route: Route?
    let gallery: Gallery

    var hudConfig: TTProgressHUDConfig = .loading

    var imageURLLoadingStates = [Int: LoadingState]()
    var previewLoadingStates = [Int: LoadingState]()
    var databaseLoadingState: LoadingState = .loading
    var previewConfig: PreviewConfig = .normal(rows: 4)

    var previews = [Int: String]()

    var thumbnails = [Int: String]()
    var imageURLs = [Int: String]()
    var originalImageURLs = [Int: String]()

    var mpvKey: String?
    var mpvImageKeys = [Int: String]()
    var mpvReloadTokens = [Int: String]()

    @BindableState var pageIndex = 0
    @BindableState var showsPanel = false
    @BindableState var sliderValue: Float = 1
    @BindableState var showsSliderPreview = false
    @BindableState var autoPlayPolicy: AutoPlayPolicy = .off

    var scaleAnchor: UnitPoint = .center
    var scale: Double = 1
    var baseScale: Double = 1
    var offset: CGSize = .zero
    var newOffset: CGSize = .zero

    // Update
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
    mutating func updateImageURLs(_ imageURLs: [Int: String], _ originalImageURLs: [Int: String]) {
        update(stored: &self.imageURLs, new: imageURLs)
        update(stored: &self.originalImageURLs, new: originalImageURLs)
    }

    // Page
    func mapFromPager(index: Int, setting: Setting, isLandscape: Bool = DeviceUtil.isLandscape) -> Int {
        guard isLandscape && setting.enablesDualPageMode
                && setting.readingDirection != .vertical
        else { return index + 1 }
        guard index > 0 else { return 1 }

        let result = setting.exceptCover ? index * 2 : index * 2 + 1

        if result + 1 == gallery.pageCount {
            return gallery.pageCount
        } else {
            return result
        }
    }
    func mapToPager(index: Int, setting: Setting, isLandscape: Bool = DeviceUtil.isLandscape) -> Int {
        guard isLandscape && setting.enablesDualPageMode
                && setting.readingDirection != .vertical
        else { return index - 1 }
        guard index > 1 else { return 0 }

        return setting.exceptCover ? index / 2 : (index - 1) / 2
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

    // Gesture
    func edgeWidth(x: Double, absWindowW: Double) -> Double {
        let marginW = absWindowW * (scale - 1) / 2
        let leadingMargin = scaleAnchor.x / 0.5 * marginW
        let trailingMargin = (1 - scaleAnchor.x) / 0.5 * marginW
        return min(max(x, -trailingMargin), leadingMargin)
    }
    func edgeHeight(y: Double, absWindowH: Double) -> Double {
        let marginH = absWindowH * (scale - 1) / 2
        let topMargin = scaleAnchor.y / 0.5 * marginH
        let bottomMargin = (1 - scaleAnchor.y) / 0.5 * marginH
        return min(max(y, -bottomMargin), topMargin)
    }
    mutating func correctOffset(absWindowW: Double, absWindowH: Double) {
        offset.width = edgeWidth(x: offset.width, absWindowW: absWindowW)
        offset.height = edgeHeight(y: offset.height, absWindowH: absWindowH)
    }
    mutating func correctScaleAnchor(point: CGPoint, absWindowW: Double, absWindowH: Double) {
        let x = min(1, max(0, point.x / absWindowW))
        let y = min(1, max(0, point.y / absWindowH))
        scaleAnchor = .init(x: x, y: y)
    }
    mutating func setOffset(_ offset: CGSize, absWindowW: Double, absWindowH: Double) {
        self.offset = offset
        correctOffset(absWindowW: absWindowW, absWindowH: absWindowH)
    }
    mutating func setScale(scale: Double, maximum: Double, absWindowW: Double, absWindowH: Double) {
        guard scale >= 1 && scale <= maximum else { return }
        self.scale = scale
        correctOffset(absWindowW: absWindowW, absWindowH: absWindowH)
    }
    mutating func onDragGestureChanged(_ value: DragGesture.Value, absWindowW: Double, absWindowH: Double) {
        guard scale > 1 else { return }
        let newX = value.translation.width + newOffset.width
        let newY = value.translation.height + newOffset.height
        let newOffsetW = edgeWidth(x: newX, absWindowW: absWindowW)
        let newOffsetH = edgeHeight(y: newY, absWindowH: absWindowH)
        setOffset(.init(width: newOffsetW, height: newOffsetH), absWindowW: absWindowW, absWindowH: absWindowH)
    }
    mutating func onMagnificationGestureChanged(
        _ value: Double, point: CGPoint?, scaleMaximum: Double,
        absWindowW: Double, absWindowH: Double
    ) {
        if value == 1 {
            baseScale = scale
        }
        if let point = point {
            correctScaleAnchor(point: point, absWindowW: absWindowW, absWindowH: absWindowH)
        }
        setScale(scale: value * baseScale, maximum: scaleMaximum, absWindowW: absWindowW, absWindowH: absWindowH)
    }
}

enum ReadingAction: BindableAction {
    case binding(BindingAction<ReadingState>)
    case setNavigation(ReadingState.Route?)

    case toggleShowsPanel
    case setPageIndex(Int)
    case setSliderValue(Float)
    case setOrientationPortrait(Bool)
    case onTimerFired
    case onAppear(Bool)

    case onWebImageRetry(Int)
    case onWebImageSucceeded(Int)
    case onWebImageFailed(Int)

    case copyImage(URL)
    case saveImage(URL)
    case saveImageDone(Bool)
    case shareImage(URL)
    case fetchImage(ReadingState.ImageAction, URL)
    case fetchImageDone(ReadingState.ImageAction, Result<UIImage, Error>)

    case onSingleTapGestureEnded(ReadingDirection)
    case onDoubleTapGestureEnded(Double, Double)
    case onMagnificationGestureChanged(Double, Double)
    case onMagnificationGestureEnded(Double, Double)
    case onDragGestureChanged(DragGesture.Value)
    case onDragGestureEnded(DragGesture.Value)

    case syncReadingProgress
    case syncPreviews([Int: String])
    case syncThumbnails([Int: String])
    case syncImageURLs([Int: String], [Int: String])

    case teardown
    case fetchDatabaseInfos
    case fetchDatabaseInfosDone(GalleryState)

    case fetchPreviews(Int)
    case fetchPreviewsDone(Int, Result<[Int: String], AppError>)

    case fetchImageURLs(Int)
    case refetchImageURLs(Int)
    case prefetchImages(Int, Int)

    case fetchThumbnails(Int)
    case fetchThumbnailsDone(Int, Result<[Int: String], AppError>)
    case fetchNormalImageURLs(Int, [Int: String])
    case fetchNormalImageURLsDone(Int, Result<([Int: String], [Int: String]), AppError>)
    case refetchNormalImageURLs(Int)
    case refetchNormalImageURLsDone(Int, Result<([Int: String], HTTPURLResponse?), AppError>)

    case fetchMPVKeys(Int, String)
    case fetchMPVKeysDone(Int, Result<(String, [Int: String]), AppError>)
    case fetchMPVImageURL(Int, Bool)
    case fetchMPVImageURLDone(Int, Result<(String, String?, String), AppError>)
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

    case .binding(\.$autoPlayPolicy):
        var effects: [Effect<ReadingAction, Never>] = [
            .cancel(id: ReadingState.TimerID())
        ]
        let timeInterval = TimeInterval(state.autoPlayPolicy.rawValue)
        if timeInterval > 0 {
            effects.append(
                Effect<RunLoop.SchedulerTimeType, Never>
                    .timer(
                        id: ReadingState.TimerID(),
                        every: .init(timeInterval),
                        on: AnySchedulerOf<RunLoop>.main
                    )
                    .map({ _ in ReadingAction.onTimerFired })
            )
        }
        return .merge(effects)

    case .binding:
        return .none

    case .setNavigation(let route):
        state.route = route
        return .none

    case .toggleShowsPanel:
        state.showsPanel.toggle()
        return .none

    case .setPageIndex(let index):
        state.pageIndex = index
        return .none

    case .setSliderValue(let value):
        state.sliderValue = value
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

    case .onTimerFired:
        state.pageIndex += 1
        return .none

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

    case .onSingleTapGestureEnded(let readingDirection):
        guard readingDirection != .vertical,
              let pointX = environment.deviceClient.touchPoint()?.x
        else { return .init(value: .toggleShowsPanel) }
        let rightToLeft = readingDirection == .rightToLeft
        if pointX < environment.deviceClient.absWindowW() * 0.2 {
            state.pageIndex += rightToLeft ? 1 : -1
        } else if pointX > environment.deviceClient.absWindowW() * (1 - 0.2) {
            state.pageIndex += rightToLeft ? -1 : 1
        } else {
            return .init(value: .toggleShowsPanel)
        }
        return .none

    case .onDoubleTapGestureEnded(let scaleMaximum, let doubleTapScale):
        let newScale = state.scale == 1 ? doubleTapScale : 1
        let absWindowW = environment.deviceClient.absWindowW()
        let absWindowH = environment.deviceClient.absWindowH()
        if let point = environment.deviceClient.touchPoint() {
            state.correctScaleAnchor(point: point, absWindowW: absWindowW, absWindowH: absWindowH)
        }
        state.setOffset(.zero, absWindowW: absWindowW, absWindowH: absWindowH)
        state.setScale(scale: newScale, maximum: scaleMaximum, absWindowW: absWindowW, absWindowH: absWindowH)
        return .none

    case .onMagnificationGestureChanged(let value, let scaleMaximum):
        let point = environment.deviceClient.touchPoint()
        let absWindowW = environment.deviceClient.absWindowW()
        let absWindowH = environment.deviceClient.absWindowH()
        state.onMagnificationGestureChanged(
            value, point: point, scaleMaximum: scaleMaximum,
            absWindowW: absWindowW, absWindowH: absWindowH
        )
        return .none

    case .onMagnificationGestureEnded(let value, let scaleMaximum):
        let point = environment.deviceClient.touchPoint()
        let absWindowW = environment.deviceClient.absWindowW()
        let absWindowH = environment.deviceClient.absWindowH()
        state.onMagnificationGestureChanged(
            value, point: point, scaleMaximum: scaleMaximum,
            absWindowW: absWindowW, absWindowH: absWindowH
        )
        if value * state.baseScale - 1 < 0.01 {
            state.setScale(
                scale: 1, maximum: scaleMaximum,
                absWindowW: absWindowW, absWindowH: absWindowH
            )
        }
        state.baseScale = state.scale
        return .none

    case .onDragGestureChanged(let value):
        let absWindowW = environment.deviceClient.absWindowW()
        let absWindowH = environment.deviceClient.absWindowH()
        state.onDragGestureChanged(value, absWindowW: absWindowW, absWindowH: absWindowH)
        return .none

    case .onDragGestureEnded(let value):
        let absWindowW = environment.deviceClient.absWindowW()
        let absWindowH = environment.deviceClient.absWindowH()
        state.onDragGestureChanged(value, absWindowW: absWindowW, absWindowH: absWindowH)
        if state.scale > 1 {
            state.newOffset.width = state.offset.width
            state.newOffset.height = state.offset.height
        }
        return .none

    case .syncReadingProgress:
        guard state.gallery.id.isValidGID else { return .none }
        return environment.databaseClient
            .updateReadingProgress(gid: state.gallery.id, progress: .init(state.sliderValue)).fireAndForget()

    case .syncPreviews(let previews):
        guard state.gallery.id.isValidGID else { return .none }
        return environment.databaseClient
            .updatePreviews(gid: state.gallery.id, previews: previews).fireAndForget()

    case .syncThumbnails(let thumbnails):
        guard state.gallery.id.isValidGID else { return .none }
        return environment.databaseClient
            .updateThumbnails(gid: state.gallery.id, thumbnails: thumbnails).fireAndForget()

    case .syncImageURLs(let imageURLs, let originalImageURLs):
        guard state.gallery.id.isValidGID else { return .none }
        return environment.databaseClient
            .updateImageURLs(gid: state.gallery.id, imageURLs: imageURLs, originalImageURLs: originalImageURLs)
            .fireAndForget()

    case .teardown:
        var effects: [Effect<ReadingAction, Never>] = [
            .cancel(id: ReadingState.CancelID()),
            .cancel(id: ReadingState.TimerID())
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
        state.previews = galleryState.previews
        state.imageURLs = galleryState.imageURLs
        state.thumbnails = galleryState.thumbnails
        state.originalImageURLs =  galleryState.originalImageURLs
        state.databaseLoadingState = .idle
        return .init(value: .setSliderValue(.init(galleryState.readingProgress)))

    case .fetchPreviews(let index):
        guard state.previewLoadingStates[index] != .loading else { return .none }
        state.previewLoadingStates[index] = .loading
        let pageNum = state.previewConfig.pageNumber(index: index)
        return GalleryPreviewsRequest(galleryURL: state.gallery.galleryURL, pageNum: pageNum)
            .effect.map({ ReadingAction.fetchPreviewsDone(index, $0) }).cancellable(id: ReadingState.CancelID())

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

    case .fetchImageURLs(let index):
        if state.mpvKey != nil {
            return .init(value: .fetchMPVImageURL(index, false))
        } else {
            return .init(value: .fetchThumbnails(index))
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
                if let urlString = state.imageURLs[index], let url = URL(string: urlString) {
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

    case .fetchThumbnails(let index):
        guard state.imageURLLoadingStates[index] != .loading else { return .none }
        state.previewConfig.batchRange(index: index).forEach {
            state.imageURLLoadingStates[$0] = .loading
        }
        let pageNum = state.previewConfig.pageNumber(index: index)
        return ThumbnailsRequest(url: state.gallery.galleryURL, pageNum: pageNum)
            .effect.map({ ReadingAction.fetchThumbnailsDone(index, $0) }).cancellable(id: ReadingState.CancelID())

    case .fetchThumbnailsDone(let index, let result):
        let batchRange = state.previewConfig.batchRange(index: index)
        switch result {
        case .success(let thumbnails):
            guard !thumbnails.isEmpty else {
                batchRange.forEach {
                    state.imageURLLoadingStates[$0] = .failed(.notFound)
                }
                return .none
            }
            if let urlString = thumbnails[index], environment.urlClient.checkIfMPVURL(URL(string: urlString)) {
                return .init(value: .fetchMPVKeys(index, urlString))
            } else {
                state.updateThumbnails(thumbnails)
                return .merge(
                    .init(value: .syncThumbnails(thumbnails)),
                    .init(value: .fetchNormalImageURLs(index, thumbnails))
                )
            }
        case .failure(let error):
            batchRange.forEach {
                state.imageURLLoadingStates[$0] = .failed(error)
            }
        }
        return .none

    case .fetchNormalImageURLs(let index, let thumbnails):
        return GalleryNormalImageURLsRequest(thumbnails: thumbnails)
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
        guard state.imageURLLoadingStates[index] != .loading else { return .none }
        state.imageURLLoadingStates[index] = .loading
        let pageNum = state.previewConfig.pageNumber(index: index)
        return GalleryNormalImageURLRefetchRequest(
            index: index, pageNum: pageNum,
            galleryURL: state.gallery.galleryURL,
            thumbnailURL: state.thumbnails[index],
            storedImageURL: state.imageURLs[index] ?? ""
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
        let reloadToken = isRefresh ? state.mpvReloadTokens[index] : nil
        return GalleryMPVImageURLRequest(
            gid: gidInteger, index: index, mpvKey: mpvKey,
            mpvImageKey: mpvImageKey, reloadToken: reloadToken
        )
        .effect.map({ ReadingAction.fetchMPVImageURLDone(index, $0) }).cancellable(id: ReadingState.CancelID())

    case .fetchMPVImageURLDone(let index, let result):
        switch result {
        case .success(let (imageURL, originalImageURL, reloadToken)):
            let imageURLs: [Int: String] = [index: imageURL]
            var originalImageURLs = [Int: String]()
            if let originalImageURL = originalImageURL {
                originalImageURLs[index] = originalImageURL
            }
            state.imageURLLoadingStates[index] = .idle
            state.mpvReloadTokens[index] = reloadToken
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
