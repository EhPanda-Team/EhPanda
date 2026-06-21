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

    var mainReducer: some ReducerOf<Self> {
        CombineReducers {
            lifecycleReducer
            databaseReducer
            imageFetchReducer
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

    var lifecycleReducer: some ReducerOf<Self> {
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
                var effects = [Effect<Action>]()
                if isPortrait {
                    effects.append(.run(operation: { _ in await appDelegateClient.setPortraitOrientationMask() }))
                    effects.append(.run(operation: { _ in await appDelegateClient.setPortraitOrientation() }))
                } else {
                    effects.append(.run(operation: { _ in await appDelegateClient.setAllOrientationMask() }))
                }
                return .merge(effects)

            case .onPerformDismiss:
                return .run(operation: { _ in await hapticsClient.generateFeedback(.light) })

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
                guard !state.isOffline,
                      state.gallery.id.isValidGID,
                      state.localPageURLs[index] == nil
                else {
                    return .none
                }
                return .send(.captureCachedPage(index))

            case .onWebImageFailed(let index):
                state.imageURLLoadingStates[index] = .failed(.webImageFailed)
                guard let url = state.localPageURLs[index], url.isFileURL,
                      state.gallery.id.isValidGID
                else {
                    return .none
                }
                let gid = state.gallery.id
                let requestID = UUID()
                state.localPageRequestID = requestID
                return .run { send in
                    let localPageURLs = await downloadClient.rescanLocalPageURLs(gid) ?? [:]
                    await send(.loadLocalPageURLsDone(requestID, localPageURLs))
                }
                .cancellable(id: ReadingCancelID.loadLocalPageURLs, cancelInFlight: true)

            case .reloadAllWebImages:
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

            case .retryAllFailedWebImages:
                guard !state.isOffline else { return .none }
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
                return .send(.fetchImage(.copy, imageURL))

            case .saveImage(let imageURL):
                return .send(.fetchImage(.save, imageURL))

            case .saveImageDone(let isSucceeded):
                state.hudConfig = isSucceeded ? .savedToPhotoLibrary : .error()
                return .send(.setNavigation(.hud))

            case .shareImage(let imageURL):
                return .send(.fetchImage(.share, imageURL))

            case .fetchImage(let action, let imageURL):
                return .run { send in
                    let result = await imageClient.fetchImageAsset(url: imageURL)
                    await send(.fetchImageDone(action, result))
                }
                .cancellable(id: ReadingCancelID.fetchImage)

            case .fetchImageDone(let action, let result):
                if case .success(let asset) = result {
                    switch action {
                    case .copy:
                        state.hudConfig = .copiedToClipboardSucceeded
                        return .merge(
                            .send(.setNavigation(.hud)),
                            .run(operation: { _ in _ = clipboardClient.saveImageData(asset.data) })
                        )
                    case .save:
                        return .run { send in
                            let success = await imageClient.saveImageDataToPhotoLibrary(asset.data)
                            await send(.saveImageDone(success))
                        }
                    case .share:
                        let shareItem: ShareItem = asset.isAnimated
                            ? .data(asset.data)
                            : .image(asset.image)
                        return .send(.setNavigation(.share(.init(value: shareItem))))
                    }
                } else {
                    state.hudConfig = .error()
                    return .send(.setNavigation(.hud))
                }

            case .teardown:
                return reduceTeardown()

            default:
                return .none
            }
        }
    }
}
