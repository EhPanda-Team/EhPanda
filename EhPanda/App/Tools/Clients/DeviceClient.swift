//
//  DeviceClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import SwiftUI
import Dependencies

struct DeviceClient {
    let isPad: () -> Bool
    let absWindowW: () -> Double
    let absWindowH: () -> Double
    let touchPoint: () -> CGPoint?
}

extension DeviceClient {
    static let live: Self = .init(
        isPad: {
            DeviceUtil.isPad
        },
        absWindowW: {
            DeviceUtil.absWindowW
        },
        absWindowH: {
            DeviceUtil.absWindowH
        },
        touchPoint: {
            TouchHandler.shared.currentPoint
        }
    )
}

// MARK: API
enum DeviceClientKey: DependencyKey {
    static let liveValue = DeviceClient.live
    static let previewValue = DeviceClient.noop
    static let testValue = DeviceClient.unimplemented
}

extension DependencyValues {
    var deviceClient: DeviceClient {
        get { self[DeviceClientKey.self] }
        set { self[DeviceClientKey.self] = newValue }
    }
}

// MARK: Test
extension DeviceClient {
    static let noop: Self = .init(
        isPad: { false },
        absWindowW: { .zero },
        absWindowH: { .zero },
        touchPoint: { .zero }
    )

    static let unimplemented: Self = .init(
        isPad: XCTestDynamicOverlay.unimplemented("\(Self.self).isPad"),
        absWindowW: XCTestDynamicOverlay.unimplemented("\(Self.self).absWindowW"),
        absWindowH: XCTestDynamicOverlay.unimplemented("\(Self.self).absWindowH"),
        touchPoint: XCTestDynamicOverlay.unimplemented("\(Self.self).touchPoint")
    )
}
