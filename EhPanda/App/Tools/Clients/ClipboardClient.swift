//
//  ClipboardClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/19.
//

import SwiftUI
import ComposableArchitecture

struct ClipboardClient {
    let url: () -> URL?
    let changeCount: () -> Int
    let save: (String) -> Effect<Never, Never>
}

extension ClipboardClient {
    static let live: Self = .init(
        url: {
            ClipboardUtil.url
        },
        changeCount: {
            UIPasteboard.general.changeCount
        },
        save: { value in
            .fireAndForget {
                ClipboardUtil.save(value: value)
            }
        }
    )
}
