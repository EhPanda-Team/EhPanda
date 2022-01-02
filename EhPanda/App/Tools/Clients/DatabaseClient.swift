//
//  DatabaseClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/02.
//

import ComposableArchitecture

struct DatabaseClient {
    let removeImageURLs: () -> Effect<Never, Never>
    let cacheGalleries: ([Gallery]) -> Effect<Never, Never>
}

extension DatabaseClient {
    static let live: Self = .init(
        removeImageURLs: {
            .fireAndForget {
                PersistenceController.removeImageURLs()
            }
        },
        cacheGalleries: { galleries in
            .fireAndForget {
                PersistenceController.add(galleries: galleries)
            }
        }
    )
}
