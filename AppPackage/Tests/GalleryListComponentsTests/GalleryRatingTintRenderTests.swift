import AppModels
@testable import GalleryListComponents
import SwiftUI
import Testing
import UIKit

/// A list row draws the user's own rating in the site's colour for it, the same `UserRatingTint.color` the detail
/// page uses (the designer).
///
/// The row is rendered rated and unrated and the pixels of the rating's colour counted: five filled caption stars
/// add far more of them than any anti-aliased edge can.
@MainActor
struct GalleryRatingTintRenderTests {
    enum Layout: CaseIterable, Sendable {
        case detail
        case thumbnail
    }

    @Test(arguments: Layout.allCases, [UserRatingTint.red, .green, .blue])
    func aRatedRowDrawsItsStarsInTheRatingsColour(_ layout: Layout, _ tint: UserRatingTint) throws {
        for scheme in [ColorScheme.light, .dark] {
            let colour = Self.resolved(tint.color, in: scheme)
            let rated = try Self.render(layout, Self.gallery(tint: tint), in: scheme)
            let unrated = try Self.render(layout, Self.gallery(tint: nil), in: scheme)

            // Counted against the same row unrated, so a badge that happens to share the colour is not a star.
            let starPixels = rated.count(matching: colour) - unrated.count(matching: colour)
            #expect(starPixels >= Self.minimumStarPixels, "Only \(starPixels) more pixels of \(tint) in \(scheme).")
        }
    }

    /// Five 12pt stars at scale 2 fill well over 5 × 100 pixels.
    private static let minimumStarPixels = 300

    private static func gallery(tint: UserRatingTint?) -> Gallery {
        Gallery(
            gid: "1", token: "token", title: "Fixture Gallery 01", rating: 5, tags: [],
            category: .misc, uploader: "Uploader", pageCount: 24, postedDate: Date(timeIntervalSince1970: 0),
            coverURL: nil, galleryURL: nil, hasRated: tint != nil, userRatingTint: tint
        )
    }

    private static func resolved(_ color: Color, in scheme: ColorScheme) -> UIColor {
        UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: scheme == .dark ? .dark : .light))
    }

    private static func render(
        _ layout: Layout, _ gallery: Gallery, in scheme: ColorScheme
    ) throws -> RenderedPixels {
        let row: AnyView = switch layout {
        case .detail: AnyView(GalleryDetailCell(gallery: gallery).frame(width: 390))
        case .thumbnail: AnyView(GalleryThumbnailCell(gallery: gallery).frame(width: 180))
        }
        let renderer = ImageRenderer(content: row
            .environment(\.colorScheme, scheme)
            .environment(\.dynamicTypeSize, .large)
            .environment(\.locale, Locale(identifier: "en_US")))
        renderer.scale = 2
        return try RenderedPixels(#require(renderer.cgImage, "The row did not render."))
    }
}

/// An image's pixels as 8-bit sRGB, for counting the ones of one colour.
private struct RenderedPixels {
    private let bytes: [UInt8]

    init(_ image: CGImage) throws {
        let width = image.width
        let height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = try #require(CGColorSpace(name: CGColorSpace.sRGB))
        try bytes.withUnsafeMutableBytes { buffer in
            let context = try #require(CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: colorSpace, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ))
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        self.bytes = bytes
    }

    /// The opaque pixels within 3 of 255 of `color` in each channel.
    func count(matching color: UIColor) -> Int {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let target = [red, green, blue].map({ Int(($0 * 255).rounded()) })
        var count = 0
        for start in stride(from: 0, to: bytes.count, by: 4) {
            let pixel = bytes[start..<start + 4]
            guard pixel.last == 255 else { continue }
            if zip(pixel.prefix(3), target).allSatisfy({ abs(Int($0) - $1) <= 3 }) {
                count += 1
            }
        }
        return count
    }
}
