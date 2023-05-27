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
    let setActive: (Bool) -> EffectTask<Never>
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

// MARK: API
enum DFClientKey: DependencyKey {
    static let liveValue = DFClient.live
    static let previewValue = DFClient.noop
    static let testValue = DFClient.unimplemented
}

extension DependencyValues {
    var dfClient: DFClient {
        get { self[DFClientKey.self] }
        set { self[DFClientKey.self] = newValue }
    }
}

// MARK: Test
extension DFClient {
    static let noop: Self = .init(
        setActive: { _ in .none }
    )

    static let unimplemented: Self = .init(
        setActive: XCTestDynamicOverlay.unimplemented("\(Self.self).setActive")
    )
}
