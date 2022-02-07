//
//  DeviceClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import SwiftUI

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
