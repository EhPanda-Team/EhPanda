//
//  LibraryClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/02.
//

import SwiftUI
import Combine
import Foundation
import Kingfisher
import SwiftyBeaver
import UIImageColors
import ComposableArchitecture

struct LibraryClient {
    let initializeLogger: () -> Effect<Never>
    let initializeWebImage: () -> Effect<Never>
    let clearWebImageDiskCache: () -> Effect<Never>
    let analyzeImageColors: (UIImage) -> Effect<UIImageColors?>
    let calculateWebImageDiskCacheSize: () -> Effect<UInt?>
}

extension LibraryClient {
    static let live: Self = .init(
        initializeLogger: {
            .run(operation: { _ in
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
            })
        },
        initializeWebImage: {
            .run(operation: { _ in
                let config = KingfisherManager.shared.downloader.sessionConfiguration
                config.httpCookieStorage = HTTPCookieStorage.shared
                KingfisherManager.shared.downloader.sessionConfiguration = config
            })
        },
        clearWebImageDiskCache: {
            .run(operation: { _ in
                KingfisherManager.shared.cache.clearDiskCache()
            })
        },
        analyzeImageColors: { image in
            Effect.publisher {
                Future { promise in
                    image.getColors(quality: .lowest) { colors in
                        promise(.success(colors))
                    }
                }
            }
        },
        calculateWebImageDiskCacheSize: {
            Effect.publisher {
                Future { promise in
                    KingfisherManager.shared.cache.calculateDiskStorageSize {
                        promise(.success(try? $0.get()))
                    }
                }
                .receive(on: DispatchQueue.main)
            }
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
        initializeLogger: { .none },
        initializeWebImage: { .none },
        clearWebImageDiskCache: { .none },
        analyzeImageColors: { _ in .none },
        calculateWebImageDiskCacheSize: { .none }
    )

    static let unimplemented: Self = .init(
        initializeLogger: XCTestDynamicOverlay.unimplemented("\(Self.self).initializeLogger"),
        initializeWebImage: XCTestDynamicOverlay.unimplemented("\(Self.self).initializeWebImage"),
        clearWebImageDiskCache: XCTestDynamicOverlay.unimplemented("\(Self.self).clearWebImageDiskCache"),
        analyzeImageColors: XCTestDynamicOverlay.unimplemented("\(Self.self).analyzeImageColors"),
        calculateWebImageDiskCacheSize:
            XCTestDynamicOverlay.unimplemented("\(Self.self).calculateWebImageDiskCacheSize")
    )
}
