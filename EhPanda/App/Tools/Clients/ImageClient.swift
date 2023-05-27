//
//  ImageClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/23.
//

import Photos
import SwiftUI
import Combine
import Kingfisher
import ComposableArchitecture

struct ImageClient {
    let prefetchImages: ([URL]) -> EffectTask<Never>
    let saveImageToPhotoLibrary: (UIImage, Bool) -> EffectTask<Bool>
    let downloadImage: (URL) -> EffectTask<Result<UIImage, Error>>
    let retrieveImage: (String) -> EffectTask<Result<UIImage, Error>>
}

extension ImageClient {
    static let live: Self = .init(
        prefetchImages: { urls in
            .fireAndForget {
                ImagePrefetcher(urls: urls).start()
            }
        },
        saveImageToPhotoLibrary: { (image, isAnimated) in
            Future { promise in
                DispatchQueue.global(qos: .utility).async {
                    if let data = image.kf.data(format: isAnimated ? .GIF : .unknown) {
                        PHPhotoLibrary.shared().performChanges {
                            let request = PHAssetCreationRequest.forAsset()
                            request.addResource(with: .photo, data: data, options: nil)
                        } completionHandler: { (isSuccess, _) in
                            promise(.success(isSuccess))
                        }
                    } else {
                        promise(.success(false))
                    }
                }
            }
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .eraseToEffect()
        },
        downloadImage: { url in
            Future { promise in
                KingfisherManager.shared.downloader.downloadImage(with: url, options: nil) { result in
                    switch result {
                    case .success(let result):
                        promise(.success(result.image))
                    case .failure(let error):
                        promise(.failure(error))
                    }
                }
            }
            .eraseToAnyPublisher()
            .catchToEffect()
        },
        retrieveImage: { key in
            Future { promise in
                KingfisherManager.shared.cache.retrieveImage(forKey: key) { result in
                    switch result {
                    case .success(let result):
                        if let image = result.image {
                            promise(.success(image))
                        } else {
                            promise(.failure(AppError.notFound))
                        }
                    case .failure(let error):
                        promise(.failure(error))
                    }
                }
            }
            .eraseToAnyPublisher()
            .catchToEffect()
        }
    )

    func fetchImage(url: URL) -> EffectTask<Result<UIImage, Error>> {
        if KingfisherManager.shared.cache.isCached(forKey: url.absoluteString) {
            return retrieveImage(url.absoluteString)
        } else {
            return downloadImage(url)
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
        prefetchImages: { _ in .none },
        saveImageToPhotoLibrary: { _, _ in .none },
        downloadImage: { _ in .none },
        retrieveImage: { _ in .none }
    )

    static let unimplemented: Self = .init(
        prefetchImages: XCTestDynamicOverlay.unimplemented("\(Self.self).prefetchImages"),
        saveImageToPhotoLibrary: XCTestDynamicOverlay.unimplemented("\(Self.self).saveImageToPhotoLibrary"),
        downloadImage: XCTestDynamicOverlay.unimplemented("\(Self.self).downloadImage"),
        retrieveImage: XCTestDynamicOverlay.unimplemented("\(Self.self).retrieveImage")
    )
}
