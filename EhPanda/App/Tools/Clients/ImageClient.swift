//
//  ImageClient.swift
//  EhPanda
//

import Photos
import SwiftUI
import Combine
import Kingfisher
import SDWebImage
import Synchronization
import ComposableArchitecture

struct ImageClient: Sendable {
    struct ImageAsset {
        let image: UIImage
        let data: Data

        var isAnimated: Bool {
            data.isAnimatedImageData || image.hasAnimatedFrames
        }
    }

    let prefetchImages: @Sendable ([URL]) -> Void
    let saveImageToPhotoLibrary: @Sendable (UIImage, Bool) async -> Bool
    let saveImageDataToPhotoLibrary: @Sendable (Data) async -> Bool
    let downloadImage: @Sendable (URL) async -> Result<UIImage, Error>
    let retrieveImage: @Sendable (String) async -> Result<UIImage, Error>
    let isCached: @Sendable (String) -> Bool
    var dataCache: DataCache = .shared
    var urlSession: URLSession = .shared
}

extension ImageClient {
    static let live: Self = .init(
        prefetchImages: { urls in
            Task {
                await withTaskGroup(of: Void.self) { group in
                    for url in urls {
                        group.addTask {
                            _ = try? await ImageClient.readerImageData(
                                url: url, dataCache: .shared, urlSession: .shared
                            )
                        }
                    }
                }
            }
        },
        saveImageToPhotoLibrary: { (image, isAnimated) in
            await withCheckedContinuation { continuation in
                let data = isAnimated
                    ? image.animatedSourceData
                    : image.kf.data(format: .unknown)
                if let data {
                    PHPhotoLibrary.shared().performChanges {
                        let request = PHAssetCreationRequest.forAsset()
                        request.addResource(with: .photo, data: data, options: nil)
                    } completionHandler: { (isSuccess, _) in
                        continuation.resume(returning: isSuccess)
                    }
                } else {
                    continuation.resume(returning: false)
                }
            }
        },
        saveImageDataToPhotoLibrary: { data in
            await Self.saveImageDataToPhotoLibrary(data)
        },
        downloadImage: { url in
            if url.isPotentiallyAnimatedImage {
                return await ImageClient.downloadAnimatedImage(url: url)
            }
            return await ImageClient.downloadStaticImage(url: url)
        },
        retrieveImage: { key in
            guard let image = await LibraryClient.live.cachedImage(key) else {
                return .failure(AppError.notFound)
            }
            return .success(image)
        },
        isCached: LibraryClient.live.isCached
    )

    static func saveImageDataToPhotoLibrary(_ data: Data) async -> Bool {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.shared().performChanges {
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            } completionHandler: { isSuccess, _ in
                continuation.resume(returning: isSuccess)
            }
        }
    }

    // Runs on the `MainActor` so the non-`Sendable` `SDWebImageCombinedOperation` it creates
    // never leaves a single isolation domain, see `AnimatedImageOperationBox`.
    @MainActor
    static func downloadAnimatedImage(
        url: URL,
        manager: SDWebImageManager = .shared
    ) async -> Result<UIImage, Error> {
        let continuationBox = ImageDownloadContinuationBox()
        let operationBox = AnimatedImageOperationBox()
        let result: Result<UIImage, Error> = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                continuationBox.setContinuation(continuation)
                let operation = manager.loadImage(
                    with: url,
                    options: [.retryFailed, .continueInBackground, .handleCookies],
                    context: [.callbackQueue: SDCallbackQueue.main],
                    progress: nil
                ) { image, data, error, _, _, _ in
                    if let image {
                        if let data {
                            Task {
                                try? await DataCache.shared.store(
                                    data,
                                    forKeys: url.imageCacheKeys(includeStableAlias: true)
                                )
                            }
                        }
                        continuationBox.resume(returning: .success(image))
                    } else {
                        continuationBox.resume(returning: .failure(error ?? AppError.notFound))
                    }
                }
                guard let operation else {
                    continuationBox.resume(returning: .failure(AppError.notFound))
                    return
                }
                operationBox.track(operation)
                continuationBox.setCancelOperation {
                    Task { @MainActor in operationBox.cancel() }
                }
            }
        } onCancel: {
            continuationBox.cancel()
        }
        return result
    }

    static func downloadStaticImage(
        url: URL,
        downloader: ImageDownloader = KingfisherManager.shared.downloader,
        cache: ImageCache = KingfisherManager.shared.cache
    ) async -> Result<UIImage, Error> {
        let continuationBox = ImageDownloadContinuationBox()
        let result: Result<UIImage, Error> = await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                continuationBox.setContinuation(continuation)
                let downloadTask = downloader.downloadImage(
                    with: url,
                    options: nil
                ) { result in
                    switch result {
                    case .success(let downloadResult):
                        Task {
                            try? await DataCache.shared.store(
                                downloadResult.originalData,
                                forKeys: url.imageCacheKeys(includeStableAlias: true)
                            )
                        }
                        cache.store(
                            downloadResult.image,
                            original: downloadResult.originalData,
                            forKey: url.stableImageCacheKey ?? url.absoluteString,
                            completionHandler: { _ in
                                continuationBox.resume(returning: .success(downloadResult.image))
                            }
                        )
                    case .failure(let error):
                        continuationBox.resume(returning: .failure(error))
                    }
                }
                continuationBox.setCancelOperation {
                    downloadTask.cancel()
                }
            }
        } onCancel: {
            continuationBox.cancel()
        }
        return result
    }

    func fetchImageAsset(url: URL) async -> Result<ImageAsset, Error> {
        do {
            let data = try await imageData(url: url)
            guard let image = data.decodedImage else {
                return .failure(AppError.parseFailed)
            }
            return .success(.init(image: image, data: data))
        } catch {
            return .failure(error)
        }
    }

    func fetchImage(url: URL) async -> Result<UIImage, Error> {
        switch await fetchImageAsset(url: url) {
        case .success(let asset):
            return .success(asset.image)
        case .failure(let error):
            return .failure(error)
        }
    }

    func fetchReaderImageAsset(url: URL) async -> ImageAsset? {
        guard let data = try? await Self.readerImageData(
            url: url, dataCache: dataCache, urlSession: urlSession
        ), let image = data.decodedImage else {
            return nil
        }
        return .init(image: image, data: data)
    }

    static func readerImageData(
        url: URL,
        dataCache: DataCache,
        urlSession: URLSession
    ) async throws -> Data {
        if url.isFileURL {
            return try Data(contentsOf: url)
        }
        let cacheKeys = url.imageCacheKeys(includeStableAlias: true)
        if let data = try await dataCache.data(forKeys: cacheKeys) {
            return data
        }
        let (data, response) = try await urlSession.data(for: URLRequest(url: url))
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw AppError.networkingFailed
        }
        try? await dataCache.store(data, forKeys: cacheKeys)
        return data
    }

    private func imageData(url: URL) async throws -> Data {
        if url.isFileURL {
            return try Data(contentsOf: url)
        }

        let cacheKeys = url.imageCacheKeys(includeStableAlias: true)
        if let data = try await dataCache.data(forKeys: cacheKeys) {
            return data
        }

        for key in cacheKeys {
            guard isCached(key) else { continue }
            guard case .success(let image) = await retrieveImage(key),
                  let data = Self.data(from: image)
            else {
                continue
            }
            try? await dataCache.store(data, forKeys: cacheKeys)
            return data
        }

        switch await downloadImage(url) {
        case .success(let image):
            guard let data = Self.data(from: image) else {
                throw AppError.notFound
            }
            try? await dataCache.store(data, forKeys: cacheKeys)
            return data

        case .failure(let error):
            throw error
        }
    }

    private static func data(from image: UIImage) -> Data? {
        image.animatedSourceData
            ?? image.sd_imageData()
            ?? image.kf.data(format: .unknown)
    }
}

// The callback APIs expose cancellation tokens after Swift task cancellation can already arrive.
private final class ImageDownloadContinuationBox: Sendable {
    private struct State: Sendable {
        var cancelOperation: (@Sendable () -> Void)?
        var continuation: CheckedContinuation<Result<UIImage, Error>, Never>?
        var isCancelled = false
        var isFinished = false
    }

    private let state = Mutex(State())

    func setContinuation(_ continuation: CheckedContinuation<Result<UIImage, Error>, Never>) {
        let shouldResumeCancellation = state.withLock { state in
            if state.isCancelled || state.isFinished {
                state.isFinished = true
                return true
            }
            state.continuation = continuation
            return false
        }

        if shouldResumeCancellation {
            continuation.resume(returning: .failure(CancellationError()))
        }
    }

    func setCancelOperation(_ cancelOperation: @escaping @Sendable () -> Void) {
        let shouldCancel = state.withLock { state in
            if state.isCancelled {
                return true
            }
            if !state.isFinished {
                state.cancelOperation = cancelOperation
            }
            return false
        }

        if shouldCancel {
            cancelOperation()
        }
    }

    func resume(returning result: Result<UIImage, Error>) {
        let continuation = state.withLock { state in
            guard !state.isFinished else {
                return nil as CheckedContinuation<Result<UIImage, Error>, Never>?
            }
            state.isFinished = true
            let continuation = state.continuation
            state.continuation = nil
            state.cancelOperation = nil
            return continuation
        }

        continuation?.resume(returning: result)
    }

    func cancel() {
        let cancellation = state.withLock { state in
            guard !state.isFinished else {
                return (
                    cancelOperation: nil as (@Sendable () -> Void)?,
                    continuation: nil as CheckedContinuation<Result<UIImage, Error>, Never>?
                )
            }
            state.isCancelled = true
            let cancelOperation = state.cancelOperation
            state.cancelOperation = nil
            let continuation = state.continuation
            if continuation != nil {
                state.isFinished = true
                state.continuation = nil
            }
            return (
                cancelOperation: cancelOperation,
                continuation: continuation
            )
        }

        cancellation.cancelOperation?()
        cancellation.continuation?.resume(returning: .failure(CancellationError()))
    }
}

// Holds the in-flight `SDWebImageCombinedOperation` so it can be cancelled when the awaiting task
// is cancelled. The operation is an Objective-C type with no `Sendable` annotation and models live
// work, so it cannot be transferred across isolation domains; confining the box to the `MainActor`
// keeps it within the actor that `downloadAnimatedImage` already runs on. The cancel handle stored
// in `ImageDownloadContinuationBox` reaches it by hopping back to the `MainActor`.
@MainActor private final class AnimatedImageOperationBox {
    private var operation: SDWebImageCombinedOperation?

    func track(_ operation: SDWebImageCombinedOperation) {
        self.operation = operation
    }

    func cancel() {
        operation?.cancel()
        operation = nil
    }
}

// MARK: API
enum ImageClientKey: DependencyKey {
    static let liveValue = ImageClient.live
    static let previewValue = ImageClient.noop
    static let testValue = ImageClient.unimplemented
}

extension DependencyValues {
    var imageClient: ImageClient {
        get { self[ImageClientKey.self] }
        set { self[ImageClientKey.self] = newValue }
    }
}

// MARK: Test
extension ImageClient {
    static let noop: Self = .init(
        prefetchImages: { _ in },
        saveImageToPhotoLibrary: { _, _ in false },
        saveImageDataToPhotoLibrary: { _ in false },
        downloadImage: { _ in .success(UIImage()) },
        retrieveImage: { _ in .success(UIImage()) },
        isCached: { _ in false }
    )

    static func placeholder<Result>() -> Result { fatalError() }

    static let unimplemented: Self = .init(
        prefetchImages: IssueReporting.unimplemented(placeholder: placeholder()),
        saveImageToPhotoLibrary: IssueReporting.unimplemented(placeholder: placeholder()),
        saveImageDataToPhotoLibrary: IssueReporting.unimplemented(placeholder: placeholder()),
        downloadImage: IssueReporting.unimplemented(placeholder: placeholder()),
        retrieveImage: IssueReporting.unimplemented(placeholder: placeholder()),
        isCached: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
