//
//  LibraryClient.swift
//  EhPanda
//

import SwiftUI
import Combine
import Foundation
import Kingfisher
import SDWebImage
import SDWebImageWebPCoder
import SwiftyBeaver
import UIImageColors
import ComposableArchitecture

struct LibraryClient: Sendable {
    let initializeLogger: @Sendable () -> Void
    let initializeWebImage: @Sendable () -> Void
    let clearWebImageDiskCache: @Sendable () -> Void
    let analyzeImageColors: @Sendable (UIImage) async -> [Color]?
    let calculateWebImageDiskCacheSize: @Sendable () async -> UInt?
}

extension LibraryClient {
    static let live: Self = .init(
        initializeLogger: {
            // MARK: SwiftyBeaver
            let file = FileDestination()
            let console = ConsoleDestination()
            let format = [
                "$Dyyyy-MM-dd HH:mm:ss.SSS$d",
                "$C$L$c $N.$F:$l - $M $X"
            ].joined(separator: " ")

            file.format = format
            file.logFileAmount = 10
            file.calendar = Calendar(identifier: .gregorian)
            file.logFileURL = FileUtil.logsDirectoryURL?
                .appendingPathComponent(Defaults.FilePath.ehpandaLog)

            console.format = format
            console.calendar = Calendar(identifier: .gregorian)
            console.asynchronously = false
            console.levelColor.verbose = "😪"
            console.levelColor.warning = "⚠️"
            console.levelColor.error = "‼️"
            console.levelColor.debug = "🐛"
            console.levelColor.info = "📖"

            SwiftyBeaver.addDestination(file)
            #if DEBUG
            SwiftyBeaver.addDestination(console)
            #endif
        },
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
        },
        clearWebImageDiskCache: {
            KingfisherManager.shared.cache.clearDiskCache()
            SDImageCache.shared.clearDisk(onCompletion: nil)
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
            return await (kingfisherSize ?? 0) + (sdWebImageSize ?? 0)
        }
    )
}

// MARK: API
enum LibraryClientKey: DependencyKey {
    static let liveValue = LibraryClient.live
    static let previewValue = LibraryClient.noop
    static let testValue = LibraryClient.unimplemented
}

extension DependencyValues {
    var libraryClient: LibraryClient {
        get { self[LibraryClientKey.self] }
        set { self[LibraryClientKey.self] = newValue }
    }
}

// MARK: Test
extension LibraryClient {
    static let noop: Self = .init(
        initializeLogger: {},
        initializeWebImage: {},
        clearWebImageDiskCache: {},
        analyzeImageColors: { _ in .none },
        calculateWebImageDiskCacheSize: { .none }
    )

    static func placeholder<Result>() -> Result { fatalError() }

    static let unimplemented: Self = .init(
        initializeLogger: IssueReporting.unimplemented(placeholder: placeholder()),
        initializeWebImage: IssueReporting.unimplemented(placeholder: placeholder()),
        clearWebImageDiskCache: IssueReporting.unimplemented(placeholder: placeholder()),
        analyzeImageColors: IssueReporting.unimplemented(placeholder: placeholder()),
        calculateWebImageDiskCacheSize:
            IssueReporting.unimplemented(placeholder: placeholder())
    )
}
