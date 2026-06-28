import SwiftUI
import ComposableArchitecture
import AnimatedImageFeature

public struct ClipboardClient: Sendable {
    public let url: @Sendable () -> URL?
    public let changeCount: @Sendable () -> Int
    public let saveText: @Sendable (String) -> Void
    public let saveImage: @Sendable (UIImage, Bool) -> Void
    public let saveImageData: @Sendable (Data) -> Bool
}

extension ClipboardClient {
    public static let live: Self = .init(
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
            UIPasteboard.general.string = text
        },
        saveImage: { (image, isAnimated) in
            if isAnimated {
                DispatchQueue.global(qos: .utility).async {
                    if let data = image.animatedSourceData,
                       let pasteboardType = data.animatedImagePasteboardType {
                        UIPasteboard.general.setData(data, forPasteboardType: pasteboardType)
                    } else {
                        UIPasteboard.general.image = image
                    }
                }
            } else {
                UIPasteboard.general.image = image
            }
        },
        saveImageData: { data in
            if let pasteboardType = data.animatedImagePasteboardType {
                UIPasteboard.general.setData(data, forPasteboardType: pasteboardType)
                return true
            }
            guard let image = data.decodedImage else {
                return false
            }
            UIPasteboard.general.image = image
            return true
        }
    )
}

// MARK: API
public enum ClipboardClientKey: DependencyKey {
    public static let liveValue = ClipboardClient.live
    public static let previewValue = ClipboardClient.noop
    public static let testValue = ClipboardClient.unimplemented
}

extension DependencyValues {
    public var clipboardClient: ClipboardClient {
        get { self[ClipboardClientKey.self] }
        set { self[ClipboardClientKey.self] = newValue }
    }
}

// MARK: Test
extension ClipboardClient {
    public static let noop: Self = .init(
        url: { nil },
        changeCount: { 0 },
        saveText: { _ in },
        saveImage: { _, _ in },
        saveImageData: { _ in false }
    )

    public static func placeholder<Result>() -> Result { fatalError() }

    public static let unimplemented: Self = .init(
        url: IssueReporting.unimplemented(placeholder: placeholder()),
        changeCount: IssueReporting.unimplemented(placeholder: placeholder()),
        saveText: IssueReporting.unimplemented(placeholder: placeholder()),
        saveImage: IssueReporting.unimplemented(placeholder: placeholder()),
        saveImageData: IssueReporting.unimplemented(placeholder: placeholder())
    )
}
