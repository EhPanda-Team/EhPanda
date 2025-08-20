//
//  ImageClient.swift
//  EhPanda
//

import Photos
import SwiftUI
import Combine
import Kingfisher
import ComposableArchitecture

struct ImageClient {
    let prefetchImages: ([URL]) -> Void
    let saveImageToPhotoLibrary: (UIImage, Bool) async -> Bool
    let downloadImage: (URL) async -> Result<UIImage, Error>
    let retrieveImage: (String) async -> Result<UIImage, Error>
}

extension ImageClient {
    static let live: Self = .init(
        prefetchImages: { urls in
            ImagePrefetcher(urls: urls).start()
        },
        saveImageToPhotoLibrary: { (image, isAnimated) in
            await withCheckedContinuation { continuation in
                if let data = image.kf.data(format: isAnimated ? .GIF : .unknown) {
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
            await withCheckedContinuation { continuation in
                KingfisherManager.shared.downloader.downloadImage(with: url, options: nil) { result in
                    switch result {
                    case .success(let result):
                        continuation.resume(returning: .success(result.image))
                    case .failure(let error):
                        continuation.resume(returning: .failure(error))
                    }
                }
            }
        },
        retrieveImage: { key in
            await withCheckedContinuation { continuation in
                KingfisherManager.shared.cache.retrieveImage(forKey: key) { result in
                    switch result {
                    case .success(let result):
                        if let image = result.image {
                            continuation.resume(returning: .success(image))
                        } else {
                            continuation.resume(returning: .failure(AppError.notFound))
                        }
                    case .failure(let error):
                        continuation.resume(returning: .failure(error))
                    }
                }
            }
        }
    )

    func fetchImage(url: URL) async -> Result<UIImage, Error> {
        if KingfisherManager.shared.cache.isCached(forKey: url.absoluteString) {
            return await retrieveImage(url.absoluteString)
        } else {
            return await downloadImage(url)
        }
    }
}

private final class ImageSaver: NSObject {
    private let completion: (Bool) -> Void

    init(completion: @escaping (Bool) -> Void) {
        self.completion = completion
    }

    func saveImage(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(didFinishSavingImage), nil)
    }
    @objc func didFinishSavingImage(
        _ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer
    ) {
        completion(error == nil)
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
        retrieveImage: { _ in .success(UIImage()) }
    )

    static func placeholder<Result>() -> Result { fatalError() }

    static let unimplemented: Self = .init(
        prefetchImages: IssueReporting.unimplemented(placeholder: placeholder()),
        saveImageToPhotoLibrary: IssueReporting.unimplemented(placeholder: placeholder()),
        downloadImage: IssueReporting.unimplemented(placeholder: placeholder()),
        retrieveImage: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
