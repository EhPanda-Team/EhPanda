import AppModels
import ComposableArchitecture
@testable import DetailFeature
import Foundation
import Sharing
import SwiftUI
import Testing
import UIKit

/// A torrent's file size follows the reader's number format.
///
/// The Torrents page showed the size as the site gives it, "26.2 MiB", with an English decimal point in every language
/// (the owner's C16 item, 19-13: the German page showed the point). The gallery's own size already follows the reader's
/// number format, and the torrent's now goes through the same ``SiteFileSize`` type.
///
/// The cell's accessibility label is the formatted count and the spoken unit, so the test reads the label: the visible
/// text is made from the same formatted count, which `SiteFileSizeTests` pins in `de_DE`.
@MainActor
struct TorrentFileSizeTests {
    private static let page = CGSize(width: 390, height: 844)

    @Test
    func aSizeTheSiteGivesAsTextIsShownInTheReadersNumberFormat() throws {
        try AccessibilityElements.read(of: Self.torrents(fileSize: "26.2 MiB"), size: Self.page) { elements in
            let labels = elements.compactMap({ $0.accessibilityLabel })
            #expect(
                labels.contains(where: { $0.contains("26,2") }),
                "No element reads the size as 26,2; the labels are \(labels)."
            )
            #expect(
                !labels.contains(where: { $0.contains("26.2") }),
                "An element still reads the size with the English decimal point; the labels are \(labels)."
            )
        }
    }

    @Test
    func aSizeThatIsNotASiteSizeIsShownUnchanged() throws {
        try AccessibilityElements.read(of: Self.torrents(fileSize: "312 MB"), size: Self.page) { elements in
            let labels = elements.compactMap({ $0.accessibilityLabel })
            #expect(labels.contains("312 MB"), "No element reads the text as given; the labels are \(labels).")
        }
    }

    /// The Torrents page with one torrent of `fileSize`, in a `de_DE` environment.
    private static func torrents(fileSize: String) -> some View {
        var state = TorrentsReducer.State()
        state.torrents = [
            GalleryTorrent(
                postedDate: Date(timeIntervalSince1970: 1_700_000_000), fileSize: fileSize,
                seedCount: 42, peerCount: 5, downloadCount: 1280, uploader: "Alice",
                fileName: "Sample Gallery.torrent", hash: "0123456789abcdef", torrentURL: .mock
            )
        ]
        let store = withDependencies {
            $0.context = .preview
            $0.defaultInMemoryStorage = InMemoryStorage()
        } operation: {
            Store(initialState: state, reducer: TorrentsReducer.init)
        }
        return TorrentsView(store: store, gid: "1", token: "a")
            .environment(\.dynamicTypeSize, .large)
            .environment(\.locale, Locale(identifier: "de_DE"))
    }
}
