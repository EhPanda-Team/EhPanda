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
    let saveText: (String) -> EffectTask<Never>
    let saveImage: (UIImage, Bool) -> EffectTask<Never>
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

// MARK: API
enum ClipboardClientKey: DependencyKey {
    static let liveValue = ClipboardClient.live
    static let testValue = ClipboardClient.noop
    static let previewValue = ClipboardClient.noop
}

extension DependencyValues {
    var clipboardClient: ClipboardClient {
        get { self[ClipboardClientKey.self] }
        set { self[ClipboardClientKey.self] = newValue }
    }
}

// MARK: Test
#if DEBUG
import XCTestDynamicOverlay

extension ClipboardClient {
    static let failing: Self = .init(
        url: {
            XCTFail("\(Self.self).url is unimplemented")
            return nil
        },
        changeCount: {
            XCTFail("\(Self.self).changeCount is unimplemented")
            return 0
        },
        saveText: { .failing("\(Self.self).saveText(\($0)) is unimplemented") },
        saveImage: { .failing("\(Self.self).saveImage(\($0), \($1)) is unimplemented") }
    )
}
#endif
extension ClipboardClient {
    static let noop: Self = .init(
        url: { nil },
        changeCount: { 0 },
        saveText: { _ in .none },
        saveImage: { _, _ in .none }
    )
}
