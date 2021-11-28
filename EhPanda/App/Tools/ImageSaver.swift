//
//  ImageSaver.swift
//  ImageSaver
//
//  Created by 荒木辰造 on R 3/08/31.
//

import SwiftUI
import Kingfisher

final class ImageSaver: NSObject, ObservableObject {
    @Published var saveSucceeded: Bool?

    func retrieveImage(url: URL) async throws -> UIImage {
        if let cachedImage = try? await retrieveCache(key: url.absoluteString) {
            return cachedImage
        } else {
            do {
                return try await downloadImage(url: url)
            } catch {
                throw error
            }
        }
    }
    private func retrieveCache(key: String) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            KingfisherManager.shared.cache.retrieveImage(forKey: key) { result in
                switch result {
                case .success(let result):
                    if let image = result.image {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(throwing: AppError.notFound)
                    }
                case .failure(let error):
                    Logger.error(error)
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    private func downloadImage(url: URL) async throws -> UIImage {
        try await withCheckedThrowingContinuation { continuation in
            KingfisherManager.shared.downloader.downloadImage(with: url, options: nil) { result in
                switch result {
                case .success(let result):
                    continuation.resume(returning: result.image)
                case .failure(let error):
                    Logger.error(error)
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func saveImage(_ image: UIImage) {
        UIImageWriteToSavedPhotosAlbum(image, self, #selector(didFinishSavingImage), nil)
        DispatchQueue.main.async { [weak self] in
            self?.saveSucceeded = nil
        }
    }
    @objc func didFinishSavingImage(
        _ image: UIImage, didFinishSavingWithError error: Error?, contextInfo: UnsafeRawPointer
    ) {
        if let error = error {
            Logger.error(error)
        }
        saveSucceeded = error == nil
    }
}
