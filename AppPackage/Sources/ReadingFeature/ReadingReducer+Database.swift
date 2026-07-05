import SwiftUI
import AppModels
import Sharing
import ComposableArchitecture
import AppTools

// MARK: - Database & Download Actions
extension ReadingReducer {
    var databaseReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .syncReadingProgress(let progress):
                @Shared(.galleryHistory) var galleryHistory
                $galleryHistory.withLock {
                    $0.updateReadingProgress(
                        gid: state.gallery.id, token: state.gallery.token, progress: progress, date: date.now
                    )
                }
                return .none

            case .syncPreviewURLs(let previewURLs):
                guard !state.isOffline else { return .none }
                return .run { [state] _ in
                    await databaseClient.updatePreviewURLs(gid: state.gallery.id, previewURLs: previewURLs)
                }

            case .syncThumbnailURLs(let thumbnailURLs):
                guard !state.isOffline else { return .none }
                return .run { [state] _ in
                    await databaseClient.updateThumbnailURLs(gid: state.gallery.id, thumbnailURLs: thumbnailURLs)
                }

            case .syncImageURLs(let imageURLs, let originalImageURLs):
                guard !state.isOffline else { return .none }
                return .run { [state] _ in
                    await databaseClient.updateImageURLs(
                        gid: state.gallery.id,
                        imageURLs: imageURLs,
                        originalImageURLs: originalImageURLs
                    )
                }

            case .fetchDatabaseInfos(let gid):
                return reduceFetchDatabaseInfos(state: &state, gid: gid)

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

    func reduceFetchDatabaseInfos(state: inout State, gid: String) -> Effect<Action> {
        if case .local(let download, let manifest) = state.contentSource {
            applyLocalSource(state: &state, download: download, manifest: manifest)
        }
        // Remote galleries are seeded from the pushing context; URL maps are rebuilt per session
        // (fetched on demand), so nothing is read from a database here. The resume position comes
        // from the persisted browsing history.
        @Shared(.galleryHistory) var galleryHistory
        state.readingProgress = galleryHistory.readingProgress(gid: gid)
        state.databaseLoadingState = .idle
        return .none
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
    /// gallery reads with no database record) and makes `localPageURLs` the only page source,
    /// clearing the remote URL maps that don't apply offline.
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
        state.databaseLoadingState = .idle
    }
}
