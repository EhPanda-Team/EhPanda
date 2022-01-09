//
//  DeviceClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

struct DeviceClient {
    let isPad: () -> Bool
}

extension DeviceClient {
    static let live: Self = .init(
        isPad: {
            DeviceUtil.isPad
        }
    )
}
