//
//  DFClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/02.
//

import Foundation
import Kingfisher
import ComposableArchitecture

struct DFClient {
    let setActive: (Bool) -> Effect<Never, Never>
}

extension DFClient {
    static let live: Self = .init(
        setActive: { newValue in
            .fireAndForget {
                if newValue {
                    URLProtocol.registerClass(DFURLProtocol.self)
                } else {
                    URLProtocol.unregisterClass(DFURLProtocol.self)
                }
                // Kingfisher
                let config = KingfisherManager.shared.downloader.sessionConfiguration
                config.protocolClasses = newValue ? [DFURLProtocol.self] : nil
                KingfisherManager.shared.downloader.sessionConfiguration = config
            }
        }
    )
}
