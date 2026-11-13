import AppModels
import ComposableArchitecture
import CookieClient
@testable import DetailFeature
import Foundation
import SwiftUI
import Testing

/// The Download, Favorite and Read buttons of the detail header are laid out by `HeaderActionsLayout`
/// from the size each button reports, so what a button reports has to be what it draws: a wrapper that
/// reports less than the glass circle covers makes that button overlap its neighbour while the other
/// gaps stay at the designed 6pt.
@MainActor
struct HeaderSectionActionSpacingTests {
    private static let designedGap: CGFloat = 6

    private struct Host: View {
        private static var unfavoritedDetail: GalleryDetail {
            var detail = GalleryDetail.preview
            detail.isFavorited = false
            return detail
        }

        var readingProgress = 0
        @AccessibilityFocusState var readFocus: Bool

        var body: some View {
            HeaderSection(
                gallery: .preview,
                galleryDetail: Self.unfavoritedDetail,
                downloadBadge: nil,
                downloadNeedsRepair: false,
                downloadFolders: [],
                isPreparingDownload: false,
                canDownload: true,
                displayJapaneseTitle: false,
                showFullTitle: false,
                showFullTitleAction: {},
                downloadAction: {},
                downloadToFolderAction: { _ in },
                manageFoldersAction: {},
                createDefaultFolderAction: {},
                favorAction: { _ in },
                unfavorAction: {},
                readingProgress: readingProgress,
                navigateReadingAction: {},
                readButtonFocus: $readFocus,
                navigateUploaderAction: {}
            )
        }
    }

    private struct ActionFrames {
        let download: CGRect
        let favorite: CGRect
        let read: CGRect
    }

    private func actionFrames(
        width: CGFloat, size: DynamicTypeSize, readingProgress: Int = 0
    ) throws -> ActionFrames {
        // `@SharedReader(.didLogin)` reads the cookie store while the header is built.
        let elements = try withDependencies {
            $0.cookieClient = .noop
        } operation: {
            try LaidOutElements(of: Host(readingProgress: readingProgress), width: width, size: size)
        }
        return try ActionFrames(
            download: #require(elements.frame(labelled: "Download")),
            favorite: #require(elements.frame(labelled: "Add to Favorites")),
            read: #require(elements.frame(labelled: "Read"))
        )
    }

    /// The designed gap between two neighbouring controls: sideways when they share a row, downwards when
    /// the layout has wrapped the second onto the next row.
    private func gap(from first: CGRect, to second: CGRect) -> CGFloat {
        abs(first.midY - second.midY) < 1 ? second.minX - first.maxX : second.minY - first.maxY
    }

    private func expectEvenlySpaced(_ frames: ActionFrames, _ context: String) {
        #expect(abs(frames.download.width - frames.favorite.width) < 0.5, "\(context): button widths differ")
        #expect(abs(frames.favorite.width - frames.read.width) < 0.5, "\(context): button widths differ")
        let downloadToFavorite = gap(from: frames.download, to: frames.favorite)
        let favoriteToRead = gap(from: frames.favorite, to: frames.read)
        #expect(
            abs(downloadToFavorite - Self.designedGap) < 0.5,
            "\(context): Download to Favorite is \(downloadToFavorite)pt, not \(Self.designedGap)pt."
        )
        #expect(
            abs(favoriteToRead - Self.designedGap) < 0.5,
            "\(context): Favorite to Read is \(favoriteToRead)pt, not \(Self.designedGap)pt."
        )
    }

    /// 375pt is the narrowest current iPhone, 402pt a current Pro, 834pt an iPad column; the three sit on one
    /// row at each of them, and 320pt (narrower than any supported phone) stresses the wrapped arrangement.
    @Test(arguments: [375, 402, 834] as [CGFloat])
    func downloadFavoriteAndReadShareOneEvenlySpacedRow(width: CGFloat) throws {
        let frames = try actionFrames(width: width, size: .large)

        #expect(abs(frames.download.midY - frames.favorite.midY) < 1)
        #expect(abs(frames.favorite.midY - frames.read.midY) < 1)
        expectEvenlySpaced(frames, "\(width)pt")
    }

    @Test(arguments: [320, 375] as [CGFloat], [DynamicTypeSize.xSmall, .xxxLarge, .accessibility3])
    func spacingHoldsWhateverTheRowArrangement(width: CGFloat, size: DynamicTypeSize) throws {
        expectEvenlySpaced(try actionFrames(width: width, size: size), "\(width)pt at \(size)")
    }

    // A saved page draws a progress ring inside the Read button, never a different button: the three controls keep one
    // size and the designed gaps, and the frames are exactly those of a gallery that was never read.
    @Test(arguments: [320, 375, 402, 834] as [CGFloat], [DynamicTypeSize.large, .accessibility3])
    func aSavedPageLeavesTheRowExactlyAsItWas(width: CGFloat, size: DynamicTypeSize) throws {
        let unread = try actionFrames(width: width, size: size)
        let resumed = try actionFrames(width: width, size: size, readingProgress: 12)

        expectEvenlySpaced(resumed, "\(width)pt at \(size) with a saved page")
        #expect(resumed.download == unread.download, "\(width)pt at \(size): Download moved")
        #expect(resumed.favorite == unread.favorite, "\(width)pt at \(size): Favorite moved")
        #expect(resumed.read == unread.read, "\(width)pt at \(size): Read changed")
    }
}
