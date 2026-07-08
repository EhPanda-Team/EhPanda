import SwiftUI
import AppModels
import Sharing
import ComposableArchitecture
import AppTools

// MARK: - Session Restore & Download Actions
extension ReadingReducer {
    var sessionReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .syncReadingProgress(let progress):
                // Debounce the persist: the page index is the hottest interaction in the app (swipe,
                // slider scrub, auto-play) and each write re-encodes the whole history array. Keep the
                // pending page in state and flush it at most once per second — plus immediately on
                // teardown/background (`.flushReadingProgress`) so a force-quit loses under a second.
                state.pendingReadingProgress = progress
                return .run { send in
                    try await clock.sleep(for: .seconds(1))
                    await send(.flushReadingProgress)
                }
                .cancellable(id: ReadingCancelID.progressFlush, cancelInFlight: true)

            case .flushReadingProgress:
                flushReadingProgress(state)
                return .none

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

            default:
                return .none
            }
        }
    }

    /// Persists the latest pending page into the shared browsing history. Called from the debounced
    /// `.flushReadingProgress` and — crucially — synchronously on reader dismissal (`.onPerformDismiss`),
    /// which runs in this child reducer before the parent nils the presentation and cancels the pending
    /// debounce. A deferred `.send` at that point would be dropped once the destination is gone.
    func flushReadingProgress(_ state: State) {
        // Nothing to persist for a gallery that can't be keyed into history (e.g. an unseeded reader
        // dismissed immediately); bail before touching the clock or the shared store.
        guard state.gallery.id.isValidGID else { return }
        @Shared(.galleryHistory) var galleryHistory
        $galleryHistory.withLock {
            $0.updateReadingProgress(
                gid: state.gallery.id, token: state.gallery.token,
                progress: state.pendingReadingProgress, date: date.now
            )
        }
    }

    func reduceObserveDownloads(gid: String) -> Effect<Action> {
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
        .cancellable(id: ReadingCancelID.observeDownloads, cancelInFlight: true)
    }

    func reduceLoadLocalPageURLs(state: inout State, gid: String) -> Effect<Action> {
        guard gid.isValidGID else {
            state.localPageRequestID = UUID()
            state.localPageURLs = .init()
            return .none
        }
        let requestID = UUID()
        state.localPageRequestID = requestID
        return .run { send in
            let localPageURLs = await downloadClient.loadLocalPageURLs(gid) ?? [:]
            await send(.loadLocalPageURLsDone(requestID, localPageURLs))
        }
        .cancellable(id: ReadingCancelID.loadLocalPageURLs, cancelInFlight: true)
    }

    func reduceLoadLocalPageURLsDone(
        state: inout State, requestID: UUID, localPageURLs: [Int: URL]
    ) -> Effect<Action> {
        guard state.localPageRequestID == requestID else { return .none }
        // Local files turned up empty; fall back to remote so the gallery is still readable.
        if case .local = state.contentSource,
           localPageURLs.isEmpty {
            state.contentSource = .remote
            state.previewURLs = .init()
            state.thumbnailURLs = .init()
            state.imageURLs = .init()
            state.originalImageURLs = .init()
            state.forceRefreshID = .init()
        }
        state.localPageURLs = localPageURLs
        localPageURLs.keys.forEach {
            state.imageURLLoadingStates[$0] = .idle
            state.previewLoadingStates[$0] = .idle
        }
        return .none
    }

    /// Enters offline mode: seeds the gallery and language from the manifest (so a downloaded
    /// gallery reads entirely from its local files and manifest) and makes `localPageURLs` the only
    /// page source, clearing the remote URL maps that don't apply offline.
    func applyLocalSource(
        state: inout State,
        download: DownloadedGallery,
        manifest: DownloadManifest
    ) {
        state.gallery = download.gallery
        state.language = manifest.language
        state.localPageURLs = download.localPageURLs
        state.previewURLs = .init()
        state.thumbnailURLs = .init()
        state.imageURLs = .init()
        state.originalImageURLs = .init()
        state.mpvKey = nil
        state.mpvImageKeys = .init()
        state.mpvSkipServerIdentifiers = .init()
        state.imageURLLoadingStates = .init()
        state.previewLoadingStates = .init()
    }
}
