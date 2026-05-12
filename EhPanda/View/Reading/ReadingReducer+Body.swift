//
//  ReadingReducer+Body.swift
//  EhPanda

import SwiftUI
import Kingfisher
import TTProgressHUD
import ComposableArchitecture

// MARK: - CancelID
enum ReadingCancelID: CaseIterable {
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

// MARK: - Reducer Body
extension ReadingReducer {
    @ReducerBuilder<State, Action>
    func makeBody() -> some Reducer<State, Action> {
        BindingReducer()
            .onChange(of: \.showsSliderPreview) { _, _ in
                .run(operation: { _ in await hapticsClient.generateFeedback(.soft) })
            }
        mainReducer
    }

    var mainReducer: some Reducer<State, Action> {
        Reduce<State, Action> { state, action in
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
                return reduceOrientation(isPortrait: isPortrait)

            case .onPerformDismiss:
                return .run(operation: { _ in await hapticsClient.generateFeedback(.light) })

            case .onAppear(let gid, let enablesLandscape):
                return reduceOnAppear(gid: gid, enablesLandscape: enablesLandscape)

            case .onWebImageRetry(let index):
                state.imageURLLoadingStates[index] = .idle
                return .none

            case .onWebImageSucceeded(let index):
                return reduceWebImageSucceeded(state: &state, index: index)

            case .onWebImageFailed(let index):
                state.imageURLLoadingStates[index] = .failed(.webImageFailed)
                return .none

            case .reloadAllWebImages:
                return reduceReloadAllWebImages(state: &state)

            case .retryAllFailedWebImages:
                return reduceRetryAllFailedWebImages(state: &state)

            case .copyImage(let imageURL):
                return .send(.fetchImage(.copy(imageURL.isAnimatedImage), imageURL))

            case .saveImage(let imageURL):
                return .send(.fetchImage(.save(imageURL.isAnimatedImage), imageURL))

            case .saveImageDone(let isSucceeded):
                state.hudConfig = isSucceeded ? .savedToPhotoLibrary : .error()
                return .send(.setNavigation(.hud))

            case .shareImage(let imageURL):
                return .send(.fetchImage(.share(imageURL.isAnimatedImage), imageURL))

            case .fetchImage(let action, let imageURL):
                return .run { send in
                    let result = await imageClient.fetchImage(url: imageURL)
                    await send(.fetchImageDone(action, result))
                }
                .cancellable(id: ReadingCancelID.fetchImage)

            case .fetchImageDone(let action, let result):
                return reduceFetchImageDone(state: &state, action: action, result: result)

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
                return reduceTeardown()

            case .fetchDatabaseInfos(let gid):
                return reduceFetchDatabaseInfos(state: &state, gid: gid)

            case .fetchDatabaseInfosDone(let galleryState):
                return reduceFetchDatabaseInfosDone(state: &state, galleryState: galleryState)

            case .observeDownloads(let gid):
                return reduceObserveDownloads(gid: gid)

            case .observeDownloadsDone:
                guard state.gallery.id.isValidGID else { return .none }
                return .send(.loadLocalPageURLs(state.gallery.id))

            case .loadLocalPageURLs(let gid):
                return reduceLoadLocalPageURLs(state: &state, gid: gid)

            case .loadLocalPageURLsDone(let requestID, let localPageURLs):
                return reduceLoadLocalPageURLsDone(
                    state: &state, requestID: requestID, localPageURLs: localPageURLs
                )

            case .fetchPreviewURLs(let index):
                return reduceFetchPreviewURLs(state: &state, index: index)

            case .fetchPreviewURLsDone(let index, let result):
                return reduceFetchPreviewURLsDone(state: &state, index: index, result: result)

            case .fetchImageURLs(let index):
                return reduceFetchImageURLs(state: &state, index: index)

            case .refetchImageURLs(let index):
                return reduceRefetchImageURLs(state: &state, index: index)

            case .prefetchImages(let index, let prefetchLimit):
                return reducePrefetchImages(state: &state, index: index, prefetchLimit: prefetchLimit)

            case .fetchThumbnailURLs(let index):
                return reduceFetchThumbnailURLs(state: &state, index: index)

            case .fetchThumbnailURLsDone(let index, let result):
                return reduceFetchThumbnailURLsDone(state: &state, index: index, result: result)

            case .fetchNormalImageURLs(let index, let thumbnailURLs):
                return reduceFetchNormalImageURLs(
                    state: &state, index: index, thumbnailURLs: thumbnailURLs
                )

            case .fetchNormalImageURLsDone(let index, let result):
                return reduceFetchNormalImageURLsDone(state: &state, index: index, result: result)

            case .refetchNormalImageURLs(let index):
                return reduceRefetchNormalImageURLs(state: &state, index: index)

            case .refetchNormalImageURLsDone(let index, let result):
                return reduceRefetchNormalImageURLsDone(state: &state, index: index, result: result)

            case .fetchMPVKeys(let index, let mpvURL):
                return reduceFetchMPVKeys(state: &state, index: index, mpvURL: mpvURL)

            case .fetchMPVKeysDone(let index, let result):
                return reduceFetchMPVKeysDone(state: &state, index: index, result: result)

            case .fetchMPVImageURL(let index, let isRefresh):
                return reduceFetchMPVImageURL(state: &state, index: index, isRefresh: isRefresh)

            case .fetchMPVImageURLDone(let index, let result):
                return reduceFetchMPVImageURLDone(state: &state, index: index, result: result)

            case .captureCachedPage(let index):
                return reduceCaptureCachedPage(state: &state, index: index)
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

// MARK: - UI Actions
extension ReadingReducer {
    func reduceOrientation(isPortrait: Bool) -> Effect<Action> {
        var effects = [Effect<Action>]()
        if isPortrait {
            effects.append(.run(operation: { _ in await appDelegateClient.setPortraitOrientationMask() }))
            effects.append(.run(operation: { _ in await appDelegateClient.setPortraitOrientation() }))
        } else {
            effects.append(.run(operation: { _ in await appDelegateClient.setAllOrientationMask() }))
        }
        return .merge(effects)
    }

    func reduceOnAppear(gid: String, enablesLandscape: Bool) -> Effect<Action> {
        var effects: [Effect<Action>] = [
            .send(.fetchDatabaseInfos(gid)),
            .send(.observeDownloads(gid)),
            .send(.loadLocalPageURLs(gid))
        ]
        if enablesLandscape {
            effects.append(.send(.setOrientationPortrait(false)))
        }
        return .merge(effects)
    }

    func reduceWebImageSucceeded(state: inout State, index: Int) -> Effect<Action> {
        state.imageURLLoadingStates[index] = .idle
        state.webImageLoadSuccessIndices.insert(index)
        guard state.contentSource == .remote,
              state.gallery.id.isValidGID,
              state.localPageURLs[index] == nil
        else {
            return .none
        }
        return .send(.captureCachedPage(index))
    }

    func reduceReloadAllWebImages(state: inout State) -> Effect<Action> {
        guard state.contentSource == .remote else {
            if case .local(let download, let manifest) = state.contentSource {
                applyLocalSource(state: &state, download: download, manifest: manifest)
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
    }

    func reduceRetryAllFailedWebImages(state: inout State) -> Effect<Action> {
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
    }

    func reduceFetchImageDone(
        state: inout State,
        action: ImageAction,
        result: Result<UIImage, Error>
    ) -> Effect<Action> {
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
            state.hudConfig = .error()
            return .send(.setNavigation(.hud))
        }
    }
}
