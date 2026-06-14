//
//  ReadingReducer+Database.swift
//  EhPanda

import SwiftUI
import ComposableArchitecture

// MARK: - Database & Download Actions
extension ReadingReducer {
    var databaseReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
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

            default:
                return .none
            }
        }
    }

    func reduceTeardown() -> Effect<Action> {
        var effects: [Effect<Action>] = [
            .merge(ReadingCancelID.allCases.map(Effect.cancel(id:)))
        ]
        effects.append(
            .run { send in
                guard await !deviceClient.isPad() else { return }
                await send(.setOrientationPortrait(true))
            }
        )
        return .merge(effects)
    }

    func reduceFetchDatabaseInfos(state: inout State, gid: String) -> Effect<Action> {
        if case .local(let download, let manifest) = state.contentSource {
            applyLocalSource(state: &state, download: download, manifest: manifest)
        } else {
            guard let gallery = databaseClient.fetchGallery(gid: gid) else { return .none }
            state.gallery = gallery
            state.language = databaseClient.fetchGalleryDetail(gid: state.gallery.id)?.language
        }
        return .run { [state] send in
            guard let dbState = await databaseClient.fetchGalleryState(gid: state.gallery.id) else { return }
            await send(.fetchDatabaseInfosDone(dbState))
        }
        .cancellable(id: ReadingCancelID.fetchDatabaseInfos)
    }

    func reduceFetchDatabaseInfosDone(state: inout State, galleryState: GalleryState) -> Effect<Action> {
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
            let localPageURLs = (try? await downloadClient.loadLocalPageURLs(gid)) ?? [:]
            await send(.loadLocalPageURLsDone(requestID, localPageURLs))
        }
        .cancellable(id: ReadingCancelID.loadLocalPageURLs, cancelInFlight: true)
    }

    func reduceLoadLocalPageURLsDone(
        state: inout State, requestID: UUID, localPageURLs: [Int: URL]
    ) -> Effect<Action> {
        guard state.localPageRequestID == requestID else { return .none }
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

    func applyLocalSource(
        state: inout State,
        download: DownloadedGallery,
        manifest: DownloadManifest
    ) {
        state.gallery = download.gallery
        state.language = manifest.language
        let imageURLs = download.localPageURLs
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
