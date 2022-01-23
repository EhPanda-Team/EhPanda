//
//  ImageClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/23.
//

import Kingfisher
import ComposableArchitecture

struct ImageClient {
    let prefetchImages: ([URL]) -> Effect<Never, Never>
}

extension ImageClient {
    static let live: Self = .init(
        prefetchImages: { urls in
            .fireAndForget {
                ImagePrefetcher(urls: urls).start()
            }
        }
    )
}
