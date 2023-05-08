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
    let initializeLogger: () -> EffectTask<Never>
    let initializeWebImage: () -> EffectTask<Never>
    let clearWebImageDiskCache: () -> EffectTask<Never>
    let analyzeImageColors: (UIImage) -> EffectTask<UIImageColors?>
    let calculateWebImageDiskCacheSize: () -> EffectTask<UInt?>
}

extension LibraryClient {
    static let live: Self = .init(
        initializeLogger: {
            .fireAndForget {
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
            }
        },
        initializeWebImage: {
            .fireAndForget {
                let config = KingfisherManager.shared.downloader.sessionConfiguration
                config.httpCookieStorage = HTTPCookieStorage.shared
                KingfisherManager.shared.downloader.sessionConfiguration = config
            }
        },
        clearWebImageDiskCache: {
            .fireAndForget {
                KingfisherManager.shared.cache.clearDiskCache()
            }
        },
        analyzeImageColors: { image in
            Future { promise in
                image.getColors(quality: .lowest) { colors in
                    promise(.success(colors))
                }
            }
            .eraseToAnyPublisher()
            .eraseToEffect()
        },
        calculateWebImageDiskCacheSize: {
            Future { promise in
                KingfisherManager.shared.cache.calculateDiskStorageSize {
                    promise(.success(try? $0.get()))
                }
            }
            .eraseToAnyPublisher()
            .receive(on: DispatchQueue.main)
            .eraseToEffect()
        }
    )
}

// MARK: API
enum LibraryClientKey: DependencyKey {
    static let liveValue = LibraryClient.live
    static let testValue = LibraryClient.noop
    static let previewValue = LibraryClient.noop
}

extension DependencyValues {
    var libraryClient: LibraryClient {
        get { self[LibraryClientKey.self] }
        set { self[LibraryClientKey.self] = newValue }
    }
}

// MARK: Test
#if DEBUG
import XCTestDynamicOverlay

extension LibraryClient {
    static let failing: Self = .init(
        initializeLogger: { .failing("\(Self.self).initializeLogger is unimplemented") },
        initializeWebImage: { .failing("\(Self.self).initializeWebImage is unimplemented") },
        clearWebImageDiskCache: { .failing("\(Self.self).clearWebImageDiskCache is unimplemented") },
        analyzeImageColors: { _ in .failing("\(Self.self).analyzeImageColors is unimplemented") },
        calculateWebImageDiskCacheSize: { .failing("\(Self.self).calculateWebImageDiskCacheSize is unimplemented") }
    )
}
#endif
extension LibraryClient {
    static let noop: Self = .init(
        initializeLogger: { .none },
        initializeWebImage: { .none },
        clearWebImageDiskCache: { .none },
        analyzeImageColors: { _ in .none },
        calculateWebImageDiskCacheSize: { .none }
    )
}
