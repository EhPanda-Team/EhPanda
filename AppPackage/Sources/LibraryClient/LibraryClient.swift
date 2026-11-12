import AnimatedImageFeature
import AppModels
import AppTools
import ComposableArchitecture
public import Dependencies
public import Foundation
import ImageColors
import Kingfisher
public import SDWebImage
import SDWebImageWebPCoder
public import SwiftUI

public struct LibraryClient: Sendable {
    public let initializeWebImage: @Sendable () -> Void
    public let removeAllCachedImages: @Sendable () async -> Void
    public let cachedImage: @Sendable (String) async -> UIImage?
    public let cachedImageData: @Sendable (String) async -> Data?
    public let removeCachedImage: @Sendable (String) async -> Void
    /// Whether any of the app's image caches holds `key`: Kingfisher's, SDWebImage's or the
    /// reader's own byte cache.
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
    public static let live = live(configuringImageSessions: { _ in })

    /// The live client, whose `initializeWebImage` passes both image downloaders' session
    /// configuration through `configuringImageSessions` before either downloader uses it.
    ///
    /// `live` leaves both configurations as they are; a capture launch adds its offline replay
    /// protocol here, so no image request can reach the network.
    public static func live(
        configuringImageSessions: @escaping @Sendable (URLSessionConfiguration) -> Void
    ) -> Self {
        .init(
            initializeWebImage: {
                let config = KingfisherManager.shared.downloader.sessionConfiguration
                config.httpCookieStorage = HTTPCookieStorage.shared
                configuringImageSessions(config)
                KingfisherManager.shared.downloader.sessionConfiguration = config

                let sdConfig = URLSessionConfiguration.default
                sdConfig.httpCookieStorage = HTTPCookieStorage.shared
                configuringImageSessions(sdConfig)
                SDWebImageDownloaderConfig.default.sessionConfiguration = sdConfig
                SDWebImageDownloader.shared.setValue(
                    "image/webp,image/apng,image/png,image/gif,image/*,*/*;q=0.8",
                    forHTTPHeaderField: "Accept"
                )
                SDImageCodersManager.shared.addCoder(SDImageWebPCoder.shared)
                @Dependency(\.dataCache) var dataCache
                dataCache.installSystemPurgeObservers()
            },
            removeAllCachedImages: {
                @Dependency(\.dataCache) var dataCache
                KingfisherManager.shared.cache.clearMemoryCache()
                SDImageCache.shared.clearMemory()
                async let dataCacheClear: Void = dataCache.removeAll()
                async let kingfisherClear: Void = KingfisherManager.shared.cache.clearDiskCache()
                async let sdWebImageClear: Void = SDImageCache.shared.clearDiskOnCompletion()
                do {
                    _ = try await (dataCacheClear, kingfisherClear, sdWebImageClear)
                } catch {
                    // Clearing image caches is best-effort; a DataCache failure must not block the other caches.
                }
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
                async let kingfisherRemove: Void = KingfisherManager.shared.cache.removeImage(forKey: key)
                async let sdWebImageRemove: Void = SDImageCache.shared.removeImage(forKey: key)
                do {
                    _ = try await (kingfisherRemove, sdWebImageRemove)
                } catch {
                    // Eviction is best-effort; both caches finish before the operation returns.
                }
            },
            isCached: { key in
                @Dependency(\.dataCache) var dataCache
                return KingfisherManager.shared.cache.isCached(forKey: key)
                    || SDImageCache.shared.imageFromMemoryCache(forKey: key) != nil
                    || SDImageCache.shared.diskImageDataExists(withKey: key)
                    || dataCache.containsData(forKey: key)
            },
            analyzeImageColors: { image in
                image.cgImage.flatMap { cgImage in
                    ImageColors.colors(from: cgImage, quality: .lowest).map { colors in
                        [colors.primary, colors.secondary, colors.detail, colors.background]
                    }
                }
            },
            calculateWebImageDiskCacheSize: {
                @Dependency(\.dataCache) var dataCache
                async let kingfisherSize = KingfisherManager.shared.cache.diskStorageSize
                async let sdWebImageSize = SDImageCache.shared.calculateSize()
                async let dataCacheSize = dataCache.totalSize()
                let kingfisherBytes: UInt
                do {
                    kingfisherBytes = try await kingfisherSize
                } catch {
                    // An unreadable cache size intentionally contributes no bytes to the aggregate.
                    kingfisherBytes = 0
                }
                let dataCacheBytes: UInt64
                do {
                    dataCacheBytes = try await dataCacheSize
                } catch {
                    // An unreadable DataCache size intentionally contributes no bytes to the aggregate.
                    dataCacheBytes = 0
                }
                let (_, sdWebImageBytes) = await sdWebImageSize
                return kingfisherBytes + sdWebImageBytes + UInt(dataCacheBytes)
            }
        )
    }
}

private func kingfisherCachedImage(forKey key: String) async -> UIImage? {
    if let image = KingfisherManager.shared.cache
        .retrieveImageInMemoryCache(forKey: key) {
        return image
    }

    do {
        return try await KingfisherManager.shared.cache.retrieveImage(forKey: key).image
    } catch {
        // An unreadable cache entry is a miss; callers can try the other cache or the network.
        return nil
    }
}

private func kingfisherCachedImageData(forKey key: String) async -> Data? {
    if let image = KingfisherManager.shared.cache
        .retrieveImageInMemoryCache(forKey: key),
       let data = image.kf.data(format: .unknown) {
        return data
    }

    do {
        if let data = try KingfisherManager.shared.cache
            .diskStorage.value(forKey: key) {
            return data
        }
    } catch {
        // A failed disk-cache read is intentionally treated as a cache miss before the fallback lookup.
    }

    do {
        let result = try await KingfisherManager.shared.cache.retrieveImage(forKey: key)
        return result.image?.kf.data(format: .unknown)
    } catch {
        // An unreadable cache entry is a miss; callers can try the other cache or the network.
        return nil
    }
}

private func sdWebImageCachedImage(forKey key: String) async -> UIImage? {
    if let image = SDImageCache.shared.imageFromCache(forKey: key) {
        return image
    }

    guard let data = await sdWebImageCachedImageData(forKey: key) else {
        return nil
    }
    return data.decodedImage
}

private func sdWebImageCachedImageData(forKey key: String) async -> Data? {
    if let image = SDImageCache.shared.imageFromMemoryCache(forKey: key),
       let data = image.animatedSourceData ?? image.sd_imageData() {
        return data
    }

    if let data = SDImageCache.shared.diskImageData(forKey: key) {
        return data
    }

    return await SDImageCache.shared.diskImageDataQuery(forKey: key)
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
