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
                navigateReadingAction: {},
                readButtonFocus: $readFocus,
                navigateUploaderAction: {}
            )
        }
    }

    private typealias ActionFrames = (download: CGRect, favorite: CGRect, read: CGRect)

    private func actionFrames(width: CGFloat, size: DynamicTypeSize) throws -> ActionFrames {
        // `@SharedReader(.didLogin)` reads the cookie store while the header is built.
        let elements = withDependencies {
            $0.cookieClient = .noop
        } operation: {
            LaidOutElements(of: Host(), width: width, size: size)
        }
        return (
            try #require(elements.frame(labelled: "Download")),
            try #require(elements.frame(labelled: "Add to Favorites")),
            try #require(elements.frame(labelled: "Read"))
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
}
