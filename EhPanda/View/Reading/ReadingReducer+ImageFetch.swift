//
//  ReadingReducer+ImageFetch.swift
//  EhPanda

import Foundation
import ComposableArchitecture

// MARK: - Image URL Fetch Actions
extension ReadingReducer {
    var imageFetchReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .fetchPreviewURLs(let index):
                guard !state.isOffline else {
                    state.previewLoadingStates[index] = .idle
                    return .none
                }
                guard state.previewLoadingStates[index] != .loading,
                      let galleryURL = state.gallery.galleryURL
                else { return .none }
                state.previewLoadingStates[index] = .loading
                let pageNum = state.previewConfig.pageNumber(index: index)
                return .run { send in
                    let response = await GalleryPreviewURLsRequest(galleryURL: galleryURL, pageNum: pageNum).response()
                    await send(.fetchPreviewURLsDone(index, response))
                }
                .cancellable(id: ReadingCancelID.fetchPreviewURLs)

            case .fetchPreviewURLsDone(let index, let result):
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
                }
                return .none

            case .fetchImageURLs(let index):
                guard !state.isOffline else {
                    state.imageURLLoadingStates[index] = .idle
                    return .none
                }
                guard state.localPageURLs[index] == nil else {
                    state.imageURLLoadingStates[index] = .idle
                    return .none
                }
                if state.mpvKey != nil {
                    return .send(.fetchMPVImageURL(index, false))
                } else {
                    return .send(.fetchThumbnailURLs(index))
                }

            case .refetchImageURLs(let index):
                guard !state.isOffline else {
                    state.imageURLLoadingStates[index] = .idle
                    return .none
                }
                guard state.localPageURLs[index] == nil else {
                    state.imageURLLoadingStates[index] = .idle
                    return .none
                }
                if state.mpvKey != nil {
                    return .send(.fetchMPVImageURL(index, true))
                } else {
                    return .send(.refetchNormalImageURLs(index))
                }

            case .prefetchImages(let index, let prefetchLimit):
                guard !state.isOffline else { return .none }
                func getPrefetchImageURLs(range: ClosedRange<Int>) -> [URL] {
                    (range.lowerBound...range.upperBound).compactMap { index in
                        if let url = state.localPageURLs[index], !url.isFileURL {
                            return url
                        }
                        if let url = state.imageURLs[index] {
                            return url
                        }
                        return nil
                    }
                }
                func getFetchImageURLIndices(range: ClosedRange<Int>) -> [Int] {
                    (range.lowerBound...range.upperBound).compactMap { index in
                        if state.localPageURLs[index] != nil {
                            return nil
                        }
                        if state.imageURLs[index] == nil,
                           state.imageURLLoadingStates[index] != .loading {
                            return index
                        }
                        return nil
                    }
                }
                var prefetchImageURLs = [URL]()
                var fetchImageURLIndices = [Int]()
                var effects = [Effect<Action>]()
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
                    effects.append(.send(.fetchImageURLs($0)))
                }
                effects.append(
                    .run { [prefetchImageURLs] _ in
                        imageClient.prefetchImages(prefetchImageURLs)
                    }
                )
                return .merge(effects)

            case .fetchThumbnailURLs(let index):
                guard !state.isOffline else {
                    state.imageURLLoadingStates[index] = .idle
                    return .none
                }
                guard state.imageURLLoadingStates[index] != .loading,
                      let galleryURL = state.gallery.galleryURL
                else { return .none }
                state.previewConfig.batchRange(index: index).forEach {
                    state.imageURLLoadingStates[$0] = .loading
                }
                let pageNum = state.previewConfig.pageNumber(index: index)
                return .run { send in
                    let response = await ThumbnailURLsRequest(galleryURL: galleryURL, pageNum: pageNum).response()
                    await send(.fetchThumbnailURLsDone(index, response))
                }
                .cancellable(id: ReadingCancelID.fetchThumbnailURLs)

            case .fetchThumbnailURLsDone(let index, let result):
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
                }
                return .none

            case .fetchNormalImageURLs(let index, let thumbnailURLs):
                guard !state.isOffline else {
                    state.imageURLLoadingStates[index] = .idle
                    return .none
                }
                return .run { send in
                    let response = await GalleryNormalImageURLsRequest(thumbnailURLs: thumbnailURLs).response()
                    await send(.fetchNormalImageURLsDone(index, response))
                }
                .cancellable(id: ReadingCancelID.fetchNormalImageURLs)

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
                    return .send(.syncImageURLs(imageURLs, originalImageURLs))
                case .failure(let error):
                    batchRange.forEach {
                        state.imageURLLoadingStates[$0] = .failed(error)
                    }
                }
                return .none

            case .refetchNormalImageURLs(let index):
                guard !state.isOffline else {
                    state.imageURLLoadingStates[index] = .idle
                    return .none
                }
                guard state.imageURLLoadingStates[index] != .loading,
                      let galleryURL = state.gallery.galleryURL,
                      let imageURL = state.imageURLs[index]
                else { return .none }
                state.imageURLLoadingStates[index] = .loading
                let pageNum = state.previewConfig.pageNumber(index: index)
                return .run { [thumbnailURL = state.thumbnailURLs[index]] send in
                    let response = await GalleryNormalImageURLRefetchRequest(
                        index: index,
                        pageNum: pageNum,
                        galleryURL: galleryURL,
                        thumbnailURL: thumbnailURL,
                        storedImageURL: imageURL
                    )
                    .response()
                    await send(.refetchNormalImageURLsDone(index, response))
                }
                .cancellable(id: ReadingCancelID.refetchNormalImageURLs)

            case .refetchNormalImageURLsDone(let index, let result):
                switch result {
                case .success(let (imageURLs, response)):
                    var effects = [Effect<Action>]()
                    if let response = response {
                        effects.append(.run(operation: { _ in cookieClient.setSkipServer(response: response) }))
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
                }
                return .none

            case .fetchMPVKeys(let index, let mpvURL):
                guard !state.isOffline else {
                    state.imageURLLoadingStates[index] = .idle
                    return .none
                }
                return .run { send in
                    let response = await MPVKeysRequest(mpvURL: mpvURL).response()
                    await send(.fetchMPVKeysDone(index, response))
                }
                .cancellable(id: ReadingCancelID.fetchMPVKeys)

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
                            .send(.fetchMPVImageURL($0, false))
                        }
                    )
                case .failure(let error):
                    batchRange.forEach {
                        state.imageURLLoadingStates[$0] = .failed(error)
                    }
                }
                return .none

            case .fetchMPVImageURL(let index, let isRefresh):
                guard !state.isOffline else {
                    state.imageURLLoadingStates[index] = .idle
                    return .none
                }
                guard let gidInteger = Int(state.gallery.id), let mpvKey = state.mpvKey,
                      let mpvImageKey = state.mpvImageKeys[index],
                      state.imageURLLoadingStates[index] != .loading
                else { return .none }
                state.imageURLLoadingStates[index] = .loading
                let skipServerIdentifier = isRefresh ? state.mpvSkipServerIdentifiers[index] : nil
                return .run { send in
                    let response = await GalleryMPVImageURLRequest(
                        gid: gidInteger,
                        index: index,
                        mpvKey: mpvKey,
                        mpvImageKey: mpvImageKey,
                        skipServerIdentifier: skipServerIdentifier
                    )
                    .response()
                    await send(.fetchMPVImageURLDone(index, response))
                }
                .cancellable(id: ReadingCancelID.fetchMPVImageURL)

            case .fetchMPVImageURLDone(let index, let result):
                switch result {
                case .success(let mpvResult):
                    let imageURLs: [Int: URL] = [index: mpvResult.imageURL]
                    var originalImageURLs = [Int: URL]()
                    if let originalImageURL = mpvResult.originalImageURL {
                        originalImageURLs[index] = originalImageURL
                    }
                    state.imageURLLoadingStates[index] = .idle
                    state.mpvSkipServerIdentifiers[index] = mpvResult.skipServerIdentifier
                    state.updateImageURLs(imageURLs, originalImageURLs)
                    return .send(.syncImageURLs(imageURLs, originalImageURLs))
                case .failure(let error):
                    state.imageURLLoadingStates[index] = .failed(error)
                }
                return .none

            case .captureCachedPage(let index):
                guard !state.isOffline,
                      state.gallery.id.isValidGID
                else {
                    return .none
                }
                let gid = state.gallery.id
                let imageURL = state.imageURLs[index]
                return .run { _ in
                    await downloadClient.captureCachedPage(
                        gid,
                        index,
                        imageURL
                    )
                }

            default:
                return .none
            }
        }
    }
}
