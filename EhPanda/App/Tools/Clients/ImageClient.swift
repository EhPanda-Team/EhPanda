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
    let prefetchImages: @Sendable ([URL]) -> Void
    let saveImageToPhotoLibrary: @Sendable (UIImage, Bool) async -> Bool
    let downloadImage: @Sendable (URL) async -> Result<UIImage, Error>
    let retrieveImage: @Sendable (String) async -> Result<UIImage, Error>
    let isCached: @Sendable (String) -> Bool
}

extension ImageClient {
    static let live: Self = .init(
        prefetchImages: { urls in
            let (sdWebImageURLs, kingfisherResources) = urls.reduce(
                into: ([URL](), [any Resource]())
            ) { result, url in
                if url.isPotentiallyAnimatedImage {
                    result.0.append(url)
                } else {
                    result.1.append(
                        KF.ImageResource(
                            downloadURL: url,
                            cacheKey: url.stableImageCacheKey ?? url.absoluteString
                        )
                    )
                }
            }
            if !kingfisherResources.isEmpty {
                ImagePrefetcher(resources: kingfisherResources).start()
            }
            if !sdWebImageURLs.isEmpty {
                SDWebImagePrefetcher.shared.prefetchURLs(
                    sdWebImageURLs,
                    options: [.lowPriority, .continueInBackground, .handleCookies],
                    context: [.animatedImageClass: SDAnimatedImage.self],
                    progress: nil,
                    completed: nil
                )
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
                ) { image, _, error, _, _, _ in
                    if let image {
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

    func fetchImage(url: URL) async -> Result<UIImage, Error> {
        if url.isFileURL {
            if let image = UIImage(contentsOfFile: url.path) {
                return .success(image)
            }
            if let data = try? Data(contentsOf: url),
               let image = UIImage(data: data) {
                return .success(image)
            }
            return .failure(AppError.notFound)
        }
        for key in url.imageCacheKeys(includeStableAlias: true)
        where isCached(key) {
            let result = await retrieveImage(key)
            if case .success = result {
                return result
            }
        }
        return await downloadImage(url)
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
        downloadImage: { _ in .success(UIImage()) },
        retrieveImage: { _ in .success(UIImage()) },
        isCached: { _ in false }
    )

    static func placeholder<Result>() -> Result { fatalError() }

    static let unimplemented: Self = .init(
        prefetchImages: IssueReporting.unimplemented(placeholder: placeholder()),
        saveImageToPhotoLibrary: IssueReporting.unimplemented(placeholder: placeholder()),
        downloadImage: IssueReporting.unimplemented(placeholder: placeholder()),
        retrieveImage: IssueReporting.unimplemented(placeholder: placeholder()),
        isCached: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
