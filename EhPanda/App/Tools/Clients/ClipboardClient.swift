//
//  ClipboardClient.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/19.
//

import SwiftUI
import ComposableArchitecture
import UniformTypeIdentifiers

struct ClipboardClient {
    let url: () -> URL?
    let changeCount: () -> Int
    let saveText: (String) -> Effect<Never, Never>
    let saveImage: (UIImage, Bool) -> Effect<Never, Never>
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
        saveText: { text in
            .fireAndForget {
                UIPasteboard.general.string = text
            }
        },
        saveImage: { (image, isAnimated) in
            .fireAndForget {
                if isAnimated {
                    DispatchQueue.global(qos: .utility).async {
                        if let data = image.kf.data(format: .GIF) {
                            UIPasteboard.general.setData(data, forPasteboardType: UTType.gif.identifier)
                        }
                    }
                } else {
                    UIPasteboard.general.image = image
                }
            }
        }
    )
}
