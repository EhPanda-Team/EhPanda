//
//  ImageClient.swift
//  EhPanda
//

import Photos
import SwiftUI
import Combine
import Kingfisher
import SDWebImage
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
                        ImageResource(
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
                let result: Result<UIImage, Error> = await withCheckedContinuation { continuation in
                    SDWebImageManager.shared.loadImage(
                        with: url,
                        options: [.retryFailed, .continueInBackground, .handleCookies],
                        context: [.callbackQueue: SDCallbackQueue.main],
                        progress: nil
                    ) { image, _, error, _, _, _ in
                        if let image {
                            continuation.resume(returning: .success(image))
                        } else {
                            continuation.resume(returning: .failure(error ?? AppError.notFound))
                        }
                    }
                }
                return result
            }
            let result: Result<UIImage, Error> = await withCheckedContinuation { continuation in
                KingfisherManager.shared.downloader.downloadImage(with: url, options: nil) { result in
                    switch result {
                    case .success(let downloadResult):
                        KingfisherManager.shared.cache.store(
                            downloadResult.image,
                            original: downloadResult.originalData,
                            forKey: url.stableImageCacheKey ?? url.absoluteString,
                            completionHandler: { _ in
                                continuation.resume(returning: .success(downloadResult.image))
                            }
                        )
                    case .failure(let error):
                        continuation.resume(returning: .failure(error))
                    }
                }
            }
            return result
        },
        retrieveImage: { key in
            guard let image = await LibraryClient.live.cachedImage(key) else {
                return .failure(AppError.notFound)
            }
            return .success(image)
        },
        isCached: LibraryClient.live.isCached
    )

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
