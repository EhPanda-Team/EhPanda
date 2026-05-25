//
//  ReadingReducer+Database.swift
//  EhPanda

import SwiftUI
import ComposableArchitecture

// MARK: - Database & Download Actions
extension ReadingReducer {
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
            state.galleryDetail = databaseClient.fetchGalleryDetail(gid: state.gallery.id)
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
            let localPageURLs: [Int: URL]
            switch await downloadClient.loadLocalPageURLs(gid) {
            case .success(let pageURLs):
                localPageURLs = pageURLs
            case .failure:
                localPageURLs = [:]
            }
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
        guard let folderURL = download.folderURL else { return }

        state.gallery = download.gallery
        state.galleryDetail = GalleryDetail(
            gid: download.gid,
            title: download.title,
            jpnTitle: download.jpnTitle,
            isFavorited: false,
            visibility: .yes,
            rating: download.rating,
            userRating: 0,
            ratingCount: 0,
            category: download.category,
            language: manifest.language,
            uploader: download.uploader ?? "",
            postedDate: download.postedDate,
            coverURL: download.coverURL,
            favoritedCount: 0,
            pageCount: download.pageCount,
            sizeCount: 0,
            sizeType: "",
            torrentCount: 0
        )
        let imageURLs = manifest.imageURLs(folderURL: folderURL)
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
