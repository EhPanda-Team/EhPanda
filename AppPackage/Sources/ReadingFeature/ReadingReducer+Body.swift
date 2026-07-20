import AppComponents
import AppTools
import ComposableArchitecture
import Kingfisher
import SwiftUI

// MARK: - CancelID
enum ReadingCancelID {
    case fetchImage
    case progressFlush
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
            sessionReducer
            imageFetchReducer
        }
        .haptics(
            unwrapping: \.destination,
            case: \.readingSetting,
            hapticsClient: hapticsClient
        )
        .haptics(
            unwrapping: \.destination,
            case: \.share,
            hapticsClient: hapticsClient
        )
        .ifLet(\.$destination, action: \.destination)
        .ifLet(\.$toast, action: \.toast)
    }

    var lifecycleReducer: some ReducerOf<Self> {
        Reduce<State, Action> { state, action in
            switch action {
            case .binding:
                return .none

            case .destination:
                return .none

            case .presentShare(let shareItem):
                state.destination = .share(shareItem)
                return .none

            case .presentReadingSetting:
                state.destination = .readingSetting(.init())
                return .none

            case .toggleShowsPanel:
                state.showsPanel.toggle()
                return .none

            case .onPerformDismiss:
                // Flush synchronously here — this runs before the parent nils the presentation and
                // cancels the pending debounce, so the last page swiped-to isn't lost on a normal close.
                flushReadingProgress(state)
                return .run(operation: { _ in await hapticsClient.generateFeedback(.light) })

            // Sent by whoever presents the reader, in the same transition that sets the
            // destination. The gid used to arrive from the view; every construction site seeds
            // `gallery`, so it was always this value.
            case .onPresented:
                let gid = state.gallery.id
                return .merge(
                    .send(.observeDownloads(gid)),
                    .send(.loadLocalPageURLs(gid))
                )

            case .onWebImageRetry(let page):
                state.imageURLLoadingStates[page] = .idle
                return .none

            case .onWebImageSucceeded(let page):
                state.imageURLLoadingStates[page] = .idle
                state.webImageLoadSuccessIndices.insert(page)
                guard !state.isOffline,
                      state.gallery.id.isValidGID,
                      state.localPageURLs[page] == nil
                else {
                    return .none
                }
                return .send(.captureCachedPage(page))

            case .onWebImageFailed(let page):
                state.imageURLLoadingStates[page] = .failed(.webImageFailed)
                guard let url = state.localPageURLs[page], url.isFileURL,
                      state.gallery.id.isValidGID
                else {
                    return .none
                }
                let gid = state.gallery.id
                let requestID = UUID()
                state.localPageRequestID = requestID
                return .run { send in
                    let localPageURLs = await downloadClient.rescanLocalPageURLs(gid) ?? [:]
                    await send(.loadLocalPageURLsDone(requestID: requestID, urls: localPageURLs))
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
                // URL maps live only in reducer state now; clearing them above is the whole reset.
                return .none

            case .retryAllFailedWebImages:
                guard !state.isOffline else { return .none }
                state.imageURLLoadingStates.forEach { (page, loadingState) in
                    if case .failed = loadingState {
                        state.imageURLLoadingStates[page] = .idle
                    }
                }
                state.previewLoadingStates.forEach { (page, loadingState) in
                    if case .failed = loadingState {
                        state.previewLoadingStates[page] = .idle
                    }
                }
                return .none

            case .copyImage(let imageURL):
                return .send(.fetchImage(action: .copy, url: imageURL))

            case .saveImage(let imageURL):
                return .send(.fetchImage(action: .save, url: imageURL))

            case .saveImageDone(let isSucceeded):
                state.toast = isSucceeded ? .savedToPhotoLibrary : .error()
                return .none

            case .shareImage(let imageURL):
                return .send(.fetchImage(action: .share, url: imageURL))

            case .fetchImage(let action, let imageURL):
                return .run { send in
                    let result = await imageClient.fetchImageAsset(url: imageURL)
                    await send(.fetchImageDone(action: action, result: result))
                }
                .cancellable(id: ReadingCancelID.fetchImage)

            case .fetchImageDone(let action, let result):
                if case .success(let asset) = result {
                    switch action {
                    case .copy:
                        state.toast = .copiedToClipboardSucceeded
                        return .run(operation: { _ in _ = clipboardClient.saveImageData(asset.data) })
                    case .save:
                        return .run { send in
                            let success = await imageClient.saveImageDataToPhotoLibrary(asset.data)
                            await send(.saveImageDone(success))
                        }
                    case .share:
                        let shareItem: ShareItem = asset.isAnimated
                            ? .data(asset.data)
                            : .image(asset.image)
                        return .send(.presentShare(.init(value: shareItem)))
                    }
                } else {
                    state.toast = .error()
                    return .none
                }

            default:
                return .none
            }
        }
    }
}
