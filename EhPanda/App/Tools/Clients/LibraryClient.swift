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
    let initializeLogger: () -> Effect<Never, Never>
    let initializeWebImage: () -> Effect<Never, Never>
    let clearWebImageDiskCache: () -> Effect<Never, Never>
    let analyzeImageColors: (UIImage) -> Effect<UIImageColors?, Never>
    let calculateWebImageDiskCacheSize: () -> Effect<Result<UInt, KingfisherError>, Never>
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
            Future(KingfisherManager.shared.cache.calculateDiskStorageSize)
                .eraseToAnyPublisher()
                .receive(on: DispatchQueue.main)
                .catchToEffect()
        }
    )
}
