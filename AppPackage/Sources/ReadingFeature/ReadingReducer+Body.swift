import AnalyticsClient
import AppComponents
import AppLaunchAutomationClient
import AppModels
import AppTools
import ClipboardClient
import ComposableArchitecture
import DownloadClient
import HapticsClient
import ImageClient
import Kingfisher
import LiveTextTranslation
import ReadingSettingFeature
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
            layoutReducer
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
                let haptics = Effect<Action>.run(operation: { _ in
                    await hapticsClient.generateFeedback(.light)
                })
                // One end-of-session signal rather than a start/end pair: a start without a matching
                // end is unanalyzable, the vendor bills per signal, and this synchronous teardown seam
                // is the one place both the visited-page count and the elapsed time are still known.
                // The duration is bucketed here rather than delegated to the SDK's duration-signal
                // pair, which transmits an exact rounded second count that D-08 forbids.
                // A reader torn down without ever being presented has no start instant and emits
                // nothing, rather than reporting a zero-duration session that never happened.
                guard let sessionStartDate = state.sessionStartDate else { return haptics }
                let elapsed = date.now.timeIntervalSince(sessionStartDate)
                let pagesRead = CountBucket(count: state.visitedPages.count)
                let duration = DurationBucket(seconds: elapsed)
                return .merge(
                    haptics,
                    .run(operation: { _ in
                        analyticsClient.send(.readingSessionEnded(pagesRead: pagesRead, duration: duration))
                    })
                )

            // Sent by whoever presents the reader, in the same transition that sets the
            // destination. The gid used to arrive from the view; every construction site seeds
            // `gallery`, so it was always this value.
            case .onPresented:
                let gid = state.gallery.id
                // Session tracking starts here and emits nothing: the signal is sent once at
                // dismissal, where both facts are known. Seed the visited set with the page the
                // reader opens on, which a resumed session makes non-zero.
                state.sessionStartDate = date.now
                state.visitedPages = [state.readingProgress]
                return .merge(
                    .send(.observeDownloads(gid)),
                    .send(.loadLocalPageURLs(gid)),
                    captureRouteEffect(gid: gid)
                )

            case .onWebImageRetry(let page):
                state.imageURLLoadingStates[page] = .idle
                return .none

            case .onWebImageSucceeded(let page, let pixelSize):
                state.imageURLLoadingStates[page] = .idle
                state.webImageLoadSuccessIndices.insert(page)
                state.recordSize(pixelSize, ofPage: page, from: .decodedImage)
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

            case .liveTextTranslationFailed(let failure):
                state.toast = .error(caption: failure.caption)
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

    /// Ends a capture route on the reading screen, which shows the reader with its control panel,
    /// with the action a tap on the page sends. The reading-live-text screen keeps the panel hidden
    /// over its Live Text. Only a capture launch has a route, and only in DEBUG builds.
    private func captureRouteEffect(gid: String) -> Effect<Action> {
        guard case .reading(let gallery, _) = appLaunchAutomationClient.current()?.captureRoute,
              gallery.id == gid
        else {
            return .none
        }
        return .send(.toggleShowsPanel)
    }
}
