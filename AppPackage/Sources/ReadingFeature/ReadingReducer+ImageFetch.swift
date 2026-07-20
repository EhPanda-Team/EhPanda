import AppModels
import AppTools
import ComposableArchitecture
import Foundation
import NetworkingFeature

// MARK: - Image URL Fetch Actions
extension ReadingReducer {
    var imageFetchReducer: some ReducerOf<Self> {
        Reduce { state, action in
            switch action {
            case .fetchPreviewURLs(let page):
                guard !state.isOffline else {
                    state.previewLoadingStates[page] = .idle
                    return .none
                }
                guard state.previewLoadingStates[page] != .loading,
                      let galleryURL = state.gallery.galleryURL
                else { return .none }
                state.previewLoadingStates[page] = .loading
                let pageNum = state.previewConfig.pageNumber(index: page)
                return .run { send in
                    do throws(AppError) {
                        let previews = try await GalleryPreviewURLsRequest(
                            galleryURL: galleryURL,
                            pageNum: pageNum
                        )
                        .response()
                        await send(.fetchPreviewURLsDone(index: page, result: .success(previews)))
                    } catch {
                        await send(.fetchPreviewURLsDone(index: page, result: .failure(error)))
                    }
                }
                .cancellable(id: ReadingCancelID.fetchPreviewURLs)

            case .fetchPreviewURLsDone(let page, let result):
                switch result {
                case .success(let previewURLs):
                    guard !previewURLs.isEmpty else {
                        state.previewLoadingStates[page] = .failed(.notFound)
                        return .none
                    }
                    state.previewLoadingStates[page] = .idle
                    state.updatePreviewURLs(previewURLs)
                    return .none
                case .failure(let error):
                    state.previewLoadingStates[page] = .failed(error)
                }
                return .none

            case .fetchImageURLs(let page):
                guard !state.isOffline else {
                    state.imageURLLoadingStates[page] = .idle
                    return .none
                }
                guard state.localPageURLs[page] == nil else {
                    state.imageURLLoadingStates[page] = .idle
                    return .none
                }
                if state.mpvKey != nil {
                    return .send(.fetchMPVImageURL(index: page, isRefresh: false))
                } else {
                    return .send(.fetchThumbnailURLs(page))
                }

            case .refetchImageURLs(let page):
                guard !state.isOffline else {
                    state.imageURLLoadingStates[page] = .idle
                    return .none
                }
                guard state.localPageURLs[page] == nil else {
                    state.imageURLLoadingStates[page] = .idle
                    return .none
                }
                if state.mpvKey != nil {
                    return .send(.fetchMPVImageURL(index: page, isRefresh: true))
                } else {
                    return .send(.refetchNormalImageURLs(page))
                }

            case .prefetchImages(let page, let prefetchLimit):
                guard !state.isOffline else { return .none }
                func getPrefetchImageURLs(range: ClosedRange<Int>) -> [URL] {
                    (range.lowerBound...range.upperBound).compactMap { page in
                        if let url = state.localPageURLs[page], !url.isFileURL {
                            return url
                        }
                        if let url = state.imageURLs[page] {
                            return url
                        }
                        return nil
                    }
                }
                func getFetchImageURLIndices(range: ClosedRange<Int>) -> [Int] {
                    (range.lowerBound...range.upperBound).compactMap { page in
                        if state.localPageURLs[page] != nil {
                            return nil
                        }
                        if state.imageURLs[page] == nil,
                           state.imageURLLoadingStates[page] != .loading {
                            return page
                        }
                        return nil
                    }
                }
                var prefetchImageURLs = [URL]()
                var fetchImageURLIndices = [Int]()
                var effects = [Effect<Action>]()
                let previousUpperBound = max(page - 2, 1)
                let previousLowerBound = max(previousUpperBound - prefetchLimit / 2, 1)
                if previousUpperBound - previousLowerBound > 0 {
                    prefetchImageURLs += getPrefetchImageURLs(range: previousLowerBound...previousUpperBound)
                    fetchImageURLIndices += getFetchImageURLIndices(range: previousLowerBound...previousUpperBound)
                }
                let nextLowerBound = min(page + 2, state.gallery.pageCount)
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

            case .fetchThumbnailURLs(let page):
                guard !state.isOffline else {
                    state.imageURLLoadingStates[page] = .idle
                    return .none
                }
                guard state.imageURLLoadingStates[page] != .loading,
                      let galleryURL = state.gallery.galleryURL
                else { return .none }
                state.previewConfig.batchRange(index: page).forEach {
                    state.imageURLLoadingStates[$0] = .loading
                }
                let pageNum = state.previewConfig.pageNumber(index: page)
                return .run { send in
                    do throws(AppError) {
                        let thumbnails = try await ThumbnailURLsRequest(
                            galleryURL: galleryURL,
                            pageNum: pageNum
                        )
                        .response()
                        await send(.fetchThumbnailURLsDone(index: page, result: .success(thumbnails)))
                    } catch {
                        await send(.fetchThumbnailURLsDone(index: page, result: .failure(error)))
                    }
                }
                .cancellable(id: ReadingCancelID.fetchThumbnailURLs)

            case .fetchThumbnailURLsDone(let page, let result):
                let batchRange = state.previewConfig.batchRange(index: page)
                switch result {
                case .success(let thumbnailURLs):
                    guard !thumbnailURLs.isEmpty else {
                        batchRange.forEach {
                            state.imageURLLoadingStates[$0] = .failed(.notFound)
                        }
                        return .none
                    }
                    if let url = thumbnailURLs[page], urlClient.checkIfMPVURL(url) {
                        return .send(.fetchMPVKeys(index: page, url: url))
                    } else {
                        state.updateThumbnailURLs(thumbnailURLs)
                        return .send(.fetchNormalImageURLs(index: page, thumbnailURLs: thumbnailURLs))
                    }
                case .failure(let error):
                    batchRange.forEach {
                        state.imageURLLoadingStates[$0] = .failed(error)
                    }
                }
                return .none

            case .fetchNormalImageURLs(let page, let thumbnailURLs):
                guard !state.isOffline else {
                    state.imageURLLoadingStates[page] = .idle
                    return .none
                }
                return .run { send in
                    do throws(AppError) {
                        let imageURLs = try await GalleryNormalImageURLsRequest(
                            thumbnailURLs: thumbnailURLs
                        )
                        .response()
                        await send(.fetchNormalImageURLsDone(index: page, result: .success(imageURLs)))
                    } catch {
                        await send(.fetchNormalImageURLsDone(index: page, result: .failure(error)))
                    }
                }
                .cancellable(id: ReadingCancelID.fetchNormalImageURLs)

            case .fetchNormalImageURLsDone(let page, let result):
                let batchRange = state.previewConfig.batchRange(index: page)
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
                    state.updateImageURLs(imageURLs, originalImageURLs: originalImageURLs)
                    return .none
                case .failure(let error):
                    batchRange.forEach {
                        state.imageURLLoadingStates[$0] = .failed(error)
                    }
                }
                return .none

            case .refetchNormalImageURLs(let page):
                guard !state.isOffline else {
                    state.imageURLLoadingStates[page] = .idle
                    return .none
                }
                guard state.imageURLLoadingStates[page] != .loading,
                      let galleryURL = state.gallery.galleryURL,
                      let imageURL = state.imageURLs[page]
                else { return .none }
                state.imageURLLoadingStates[page] = .loading
                let pageNum = state.previewConfig.pageNumber(index: page)
                let host = state.setting.galleryHost
                return .run { [thumbnailURL = state.thumbnailURLs[page]] send in
                    do throws(AppError) {
                        let imageURLs = try await GalleryNormalImageURLRefetchRequest(
                            host: host,
                            index: page,
                            pageNum: pageNum,
                            galleryURL: galleryURL,
                            thumbnailURL: thumbnailURL,
                            storedImageURL: imageURL
                        )
                        .response()
                        await send(.refetchNormalImageURLsDone(index: page, host: host, result: .success(imageURLs)))
                    } catch {
                        await send(.refetchNormalImageURLsDone(index: page, host: host, result: .failure(error)))
                    }
                }
                .cancellable(id: ReadingCancelID.refetchNormalImageURLs)

            case .refetchNormalImageURLsDone(let page, let host, let result):
                switch result {
                case .success(let (imageURLs, response)):
                    var effects = [Effect<Action>]()
                    if let response = response {
                        effects.append(.run(operation: { _ in
                            cookieClient.setSkipServer(
                                response: response,
                                host: host
                            )
                        }))
                    }
                    guard !imageURLs.isEmpty else {
                        state.imageURLLoadingStates[page] = .failed(.notFound)
                        return effects.isEmpty ? .none : .merge(effects)
                    }
                    state.imageURLLoadingStates[page] = .idle
                    state.updateImageURLs(imageURLs, originalImageURLs: [:])
                    return effects.isEmpty ? .none : .merge(effects)
                case .failure(let error):
                    state.imageURLLoadingStates[page] = .failed(error)
                }
                return .none

            case .fetchMPVKeys(let page, let mpvURL):
                guard !state.isOffline else {
                    state.imageURLLoadingStates[page] = .idle
                    return .none
                }
                return .run { send in
                    do throws(AppError) {
                        let keys = try await MPVKeysRequest(mpvURL: mpvURL).response()
                        await send(.fetchMPVKeysDone(index: page, result: .success(keys)))
                    } catch {
                        await send(.fetchMPVKeysDone(index: page, result: .failure(error)))
                    }
                }
                .cancellable(id: ReadingCancelID.fetchMPVKeys)

            case .fetchMPVKeysDone(let page, let result):
                let batchRange = state.previewConfig.batchRange(index: page)
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
                            .send(.fetchMPVImageURL(index: $0, isRefresh: false))
                        }
                    )
                case .failure(let error):
                    batchRange.forEach {
                        state.imageURLLoadingStates[$0] = .failed(error)
                    }
                }
                return .none

            case .fetchMPVImageURL(let page, let isRefresh):
                guard !state.isOffline else {
                    state.imageURLLoadingStates[page] = .idle
                    return .none
                }
                guard let gidInteger = Int(state.gallery.id), let mpvKey = state.mpvKey,
                      let mpvImageKey = state.mpvImageKeys[page],
                      state.imageURLLoadingStates[page] != .loading
                else { return .none }
                state.imageURLLoadingStates[page] = .loading
                let skipServerIdentifier = isRefresh ? state.mpvSkipServerIdentifiers[page] : nil
                let host = state.setting.galleryHost
                return .run { send in
                    do throws(AppError) {
                        let imageURL = try await GalleryMPVImageURLRequest(
                            host: host,
                            gid: gidInteger,
                            index: page,
                            mpvKey: mpvKey,
                            mpvImageKey: mpvImageKey,
                            skipServerIdentifier: skipServerIdentifier
                        )
                        .response()
                        await send(.fetchMPVImageURLDone(index: page, result: .success(imageURL)))
                    } catch {
                        await send(.fetchMPVImageURLDone(index: page, result: .failure(error)))
                    }
                }
                .cancellable(id: ReadingCancelID.fetchMPVImageURL)

            case .fetchMPVImageURLDone(let page, let result):
                switch result {
                case .success(let mpvResult):
                    let imageURLs: [Int: URL] = [page: mpvResult.imageURL]
                    var originalImageURLs = [Int: URL]()
                    if let originalImageURL = mpvResult.originalImageURL {
                        originalImageURLs[page] = originalImageURL
                    }
                    state.imageURLLoadingStates[page] = .idle
                    state.mpvSkipServerIdentifiers[page] = mpvResult.skipServerIdentifier
                    state.updateImageURLs(imageURLs, originalImageURLs: originalImageURLs)
                    return .none
                case .failure(let error):
                    state.imageURLLoadingStates[page] = .failed(error)
                }
                return .none

            case .captureCachedPage(let page):
                guard !state.isOffline,
                      state.gallery.id.isValidGID
                else {
                    return .none
                }
                let gid = state.gallery.id
                let imageURL = state.imageURLs[page]
                return .run { _ in
                    await downloadClient.captureCachedPage(
                        gid,
                        page,
                        imageURL
                    )
                }

            default:
                return .none
            }
        }
    }
}
