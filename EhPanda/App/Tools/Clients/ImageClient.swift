//
//  ImageClient.swift
//  EhPanda
//

import Photos
import SwiftUI
import Combine
import Kingfisher
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
        }
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

    // Exports read the same owned bytes the reader display caches, so save/share/copy
    // route by image content (DES-1) instead of the request URL's extension.
    func fetchImageAsset(url: URL) async -> Result<ImageAsset, Error> {
        do {
            let data = try await Self.readerImageData(
                url: url, dataCache: dataCache, urlSession: urlSession
            )
            guard let image = data.decodedImage else {
                return .failure(AppError.parseFailed)
            }
            return .success(.init(image: image, data: data))
        } catch {
            return .failure(error)
        }
    }

    func fetchReaderImageAsset(
        url: URL,
        onProgress: (@MainActor @Sendable (Double) -> Void)? = nil
    ) async -> ImageAsset? {
        guard let data = try? await Self.readerImageData(
            url: url, dataCache: dataCache, urlSession: urlSession, onProgress: onProgress
        ), let image = data.decodedImage else {
            return nil
        }
        return .init(image: image, data: data)
    }

    static func readerImageData(
        url: URL,
        dataCache: DataCache,
        urlSession: URLSession,
        onProgress: (@MainActor @Sendable (Double) -> Void)? = nil
    ) async throws -> Data {
        if url.isFileURL {
            return try Data(contentsOf: url)
        }
        let cacheKeys = url.imageCacheKeys(includeStableAlias: true)
        if let data = await dataCache.data(forKeys: cacheKeys) {
            return data
        }
        let data = try await downloadReaderData(
            url: url, urlSession: urlSession, onProgress: onProgress
        )
        // Only cache decodable image bytes so a 200 carrying an HTML/error body
        // (e.g. an E-H bandwidth notice) can't poison the key until expiry.
        guard data.decodedImage != nil else {
            throw AppError.parseFailed
        }
        try? await dataCache.store(data, forKeys: cacheKeys)
        return data
    }

    // Streams the body via `bytes(for:)` to drive per-image progress when a
    // handler is supplied; otherwise the single-shot `data(for:)` keeps the
    // progress-less prefetch path fast.
    private static func downloadReaderData(
        url: URL,
        urlSession: URLSession,
        onProgress: (@MainActor @Sendable (Double) -> Void)?
    ) async throws -> Data {
        guard let onProgress else {
            let (data, response) = try await urlSession.data(for: URLRequest(url: url))
            try validateReaderResponse(response)
            return data
        }
        let (bytes, response) = try await urlSession.bytes(for: URLRequest(url: url))
        try validateReaderResponse(response)
        let expectedLength = response.expectedContentLength
        var data = Data()
        if expectedLength > 0 {
            data.reserveCapacity(Int(expectedLength))
        }
        var lastReportedFraction = 0.0
        for try await byte in bytes {
            data.append(byte)
            guard expectedLength > 0 else { continue }
            let fraction = min(Double(data.count) / Double(expectedLength), 1)
            if fraction - lastReportedFraction >= 0.01 {
                lastReportedFraction = fraction
                await onProgress(fraction)
            }
        }
        return data
    }

    private static func validateReaderResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw AppError.networkingFailed
        }
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
        saveImageDataToPhotoLibrary: { _ in false }
    )

    static func placeholder<Result>() -> Result { fatalError() }

    static let unimplemented: Self = .init(
        prefetchImages: IssueReporting.unimplemented(placeholder: placeholder()),
        saveImageToPhotoLibrary: IssueReporting.unimplemented(placeholder: placeholder()),
        saveImageDataToPhotoLibrary: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
