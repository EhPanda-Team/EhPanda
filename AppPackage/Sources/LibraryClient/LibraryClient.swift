import SwiftUI
import AppModels
import Combine
import Foundation
import Kingfisher
import SDWebImage
import SDWebImageWebPCoder
import UIImageColors
import ComposableArchitecture
import AppTools
import AnimatedImageFeature

public struct LibraryClient: Sendable {
    public let initializeWebImage: @Sendable () -> Void
    public let removeAllCachedImages: @Sendable () async -> Void
    public let cachedImage: @Sendable (String) async -> UIImage?
    public let cachedImageData: @Sendable (String) async -> Data?
    public let removeCachedImage: @Sendable (String) async -> Void
    public let isCached: @Sendable (String) -> Bool
    public let analyzeImageColors: @Sendable (UIImage) async -> [Color]?
    public let calculateWebImageDiskCacheSize: @Sendable () async -> UInt?

    public init(
        initializeWebImage: @escaping @Sendable () -> Void,
        removeAllCachedImages: @escaping @Sendable () async -> Void,
        cachedImage: @escaping @Sendable (String) async -> UIImage?,
        cachedImageData: @escaping @Sendable (String) async -> Data?,
        removeCachedImage: @escaping @Sendable (String) async -> Void,
        isCached: @escaping @Sendable (String) -> Bool,
        analyzeImageColors: @escaping @Sendable (UIImage) async -> [Color]?,
        calculateWebImageDiskCacheSize: @escaping @Sendable () async -> UInt?
    ) {
        self.initializeWebImage = initializeWebImage
        self.removeAllCachedImages = removeAllCachedImages
        self.cachedImage = cachedImage
        self.cachedImageData = cachedImageData
        self.removeCachedImage = removeCachedImage
        self.isCached = isCached
        self.analyzeImageColors = analyzeImageColors
        self.calculateWebImageDiskCacheSize = calculateWebImageDiskCacheSize
    }
}

extension LibraryClient {
    public static let live: Self = .init(
        initializeWebImage: {
            let config = KingfisherManager.shared.downloader.sessionConfiguration
            config.httpCookieStorage = HTTPCookieStorage.shared
            KingfisherManager.shared.downloader.sessionConfiguration = config

            let sdConfig = URLSessionConfiguration.default
            sdConfig.httpCookieStorage = HTTPCookieStorage.shared
            SDWebImageDownloaderConfig.default.sessionConfiguration = sdConfig
            SDWebImageDownloader.shared.setValue(
                "image/webp,image/apng,image/png,image/gif,image/*,*/*;q=0.8",
                forHTTPHeaderField: "Accept"
            )
            SDImageCodersManager.shared.addCoder(SDImageWebPCoder.shared)
            DataCache.installSystemPurgeObservers()
        },
        removeAllCachedImages: {
            KingfisherManager.shared.cache.clearMemoryCache()
            SDImageCache.shared.clearMemory()
            async let dataCacheClear: Void = DataCache.shared.removeAll()
            async let kingfisherClear: Void = withCheckedContinuation { continuation in
                KingfisherManager.shared.cache.clearDiskCache {
                    continuation.resume()
                }
            }
            async let sdWebImageClear: Void = withCheckedContinuation { continuation in
                SDImageCache.shared.clearDisk {
                    continuation.resume()
                }
            }
            _ = try? await (dataCacheClear, kingfisherClear, sdWebImageClear)
        },
        cachedImage: { key in
            if let image = await kingfisherCachedImage(forKey: key) {
                return image
            }
            return await sdWebImageCachedImage(forKey: key)
        },
        cachedImageData: { key in
            if let data = await kingfisherCachedImageData(forKey: key) {
                return data
            }
            return await sdWebImageCachedImageData(forKey: key)
        },
        removeCachedImage: { key in
            async let kingfisherRemove: Void = withCheckedContinuation { continuation in
                KingfisherManager.shared.cache.removeImage(forKey: key) {
                    continuation.resume()
                }
            }
            async let sdWebImageRemove: Void = withCheckedContinuation { continuation in
                SDImageCache.shared.removeImage(forKey: key) {
                    continuation.resume()
                }
            }
            _ = await (kingfisherRemove, sdWebImageRemove)
        },
        isCached: { key in
            KingfisherManager.shared.cache.isCached(forKey: key)
                || SDImageCache.shared.imageFromMemoryCache(forKey: key) != nil
                || SDImageCache.shared.diskImageDataExists(withKey: key)
        },
        analyzeImageColors: { image in
            await withCheckedContinuation { continuation in
                image.getColors(quality: .lowest) { colors in
                    continuation.resume(
                        returning: colors.map {
                            [
                                $0.primary, $0.secondary,
                                $0.detail, $0.background
                            ]
                            .map(Color.init)
                        }
                    )
                }
            }
        },
        calculateWebImageDiskCacheSize: {
            async let kingfisherSize: UInt? = withCheckedContinuation { continuation in
                KingfisherManager.shared.cache.calculateDiskStorageSize {
                    continuation.resume(returning: try? $0.get())
                }
            }
            async let sdWebImageSize: UInt? = withCheckedContinuation { continuation in
                SDImageCache.shared.calculateSize { _, totalSize in
                    continuation.resume(returning: UInt(totalSize))
                }
            }
            async let dataCacheSize = try? DataCache.shared.totalSize()
            return await (kingfisherSize ?? 0) + (sdWebImageSize ?? 0) + UInt(dataCacheSize ?? 0)
        }
    )
}

private func kingfisherCachedImage(forKey key: String) async -> UIImage? {
    if let image = KingfisherManager.shared.cache
        .retrieveImageInMemoryCache(forKey: key) {
        return image
    }

    return await withCheckedContinuation { continuation in
        KingfisherManager.shared.cache
            .retrieveImage(forKey: key) { result in
                switch result {
                case .success(let value):
                    continuation.resume(returning: value.image)

                case .failure:
                    continuation.resume(returning: nil)
                }
            }
    }
}

private func kingfisherCachedImageData(forKey key: String) async -> Data? {
    if let image = KingfisherManager.shared.cache
        .retrieveImageInMemoryCache(forKey: key),
       let data = image.kf.data(format: .unknown) {
        return data
    }

    if let data = try? KingfisherManager.shared.cache
        .diskStorage.value(forKey: key) {
        return data
    }

    return await withCheckedContinuation { continuation in
        KingfisherManager.shared.cache
            .retrieveImage(forKey: key) { result in
                switch result {
                case .success(let value):
                    continuation.resume(
                        returning: value.image.flatMap {
                            $0.kf.data(format: .unknown)
                        }
                    )

                case .failure:
                    continuation.resume(returning: nil)
                }
            }
    }
}

private func sdWebImageCachedImage(forKey key: String) async -> UIImage? {
    if let image = SDImageCache.shared.imageFromCache(forKey: key) {
        return image
    }

    guard let data = await sdWebImageCachedImageData(forKey: key) else {
        return nil
    }
    return image(from: data)
}

private func sdWebImageCachedImageData(forKey key: String) async -> Data? {
    if let image = SDImageCache.shared.imageFromMemoryCache(forKey: key),
       let data = image.animatedSourceData ?? image.sd_imageData() {
        return data
    }

    if let data = SDImageCache.shared.diskImageData(forKey: key) {
        return data
    }

    return await withCheckedContinuation { continuation in
        SDImageCache.shared.diskImageDataQuery(forKey: key) { data in
            continuation.resume(returning: data)
        }
    }
}

private func image(from data: Data) -> UIImage? {
    data.decodedImage
}

// MARK: API
public enum LibraryClientKey: DependencyKey {
    public static let liveValue = LibraryClient.live
    public static let previewValue = LibraryClient.noop
    public static let testValue = LibraryClient.unimplemented
}

extension DependencyValues {
    public var libraryClient: LibraryClient {
        get { self[LibraryClientKey.self] }
        set { self[LibraryClientKey.self] = newValue }
    }
}

// MARK: Test
extension LibraryClient {
    public static let noop: Self = .init(
        initializeWebImage: {},
        removeAllCachedImages: {},
        cachedImage: { _ in nil },
        cachedImageData: { _ in nil },
        removeCachedImage: { _ in },
        isCached: { _ in false },
        analyzeImageColors: { _ in .none },
        calculateWebImageDiskCacheSize: { .none }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        initializeWebImage: IssueReporting.unimplemented(placeholder: placeholder()),
        removeAllCachedImages: IssueReporting.unimplemented(placeholder: placeholder()),
        cachedImage: IssueReporting.unimplemented(placeholder: placeholder()),
        cachedImageData: IssueReporting.unimplemented(placeholder: placeholder()),
        removeCachedImage: IssueReporting.unimplemented(placeholder: placeholder()),
        isCached: IssueReporting.unimplemented(placeholder: placeholder()),
        analyzeImageColors: IssueReporting.unimplemented(placeholder: placeholder()),
        calculateWebImageDiskCacheSize:
            IssueReporting.unimplemented(placeholder: placeholder())
    )
}
