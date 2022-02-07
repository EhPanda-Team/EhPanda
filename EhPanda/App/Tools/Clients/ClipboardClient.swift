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
    let saveText: (String) -> Effect<Never, Never>
    let saveImage: (UIImage) -> Effect<Never, Never>
}

extension ClipboardClient {
    static let live: Self = .init(
        url: {
            if UIPasteboard.general.hasURLs {
                return UIPasteboard.general.url
            } else {
                return URL(string: UIPasteboard.general.string ?? "")
            }
        },
        changeCount: {
            UIPasteboard.general.changeCount
        },
        saveText: { value in
            .fireAndForget {
                UIPasteboard.general.string = value
            }
        },
        saveImage: { value in
            .fireAndForget {
                UIPasteboard.general.image = value
            }
        }
    )
}
