@testable import DetailFeature
import SwiftUI
import Testing
import UIKit

/// The collapsed Detail card's Show and Unblock pills (UI-SPEC C-8, rev 1.1): in dark a `systemGray3` capsule with a
/// 1pt `systemGray` edge, which the old `secondarySystemGroupedBackground` fill left nearly invisible on the card's
/// `systemGray5` (1.2:1); in light a white capsule and no edge, as before.
///
/// The card is rendered in each appearance and its pixels counted by colour: the two capsules' fill covers far more
/// of the image than any text edge can, and the edge is a ring around both.
@MainActor
struct BlockedCommentCardPillColorTests {
    @Test
    func inDarkThePillsAreSystemGray3WithASystemGrayEdge() throws {
        let pixels = try Self.renderedCard(in: .dark)

        let fill = pixels.count(matching: Self.resolved(.systemGray3, in: .dark))
        let edge = pixels.count(matching: Self.resolved(.systemGray, in: .dark))
        let oldFill = pixels.count(matching: Self.resolved(.secondarySystemGroupedBackground, in: .dark))

        #expect(fill >= Self.minimumFillPixels, "Only \(fill) systemGray3 pixels: the pills have another fill.")
        #expect(edge >= Self.minimumEdgePixels, "Only \(edge) systemGray pixels: the pills have no edge.")
        #expect(oldFill < Self.minimumEdgePixels, "\(oldFill) pixels still have the old fill.")
    }

    @Test
    func inLightThePillsAreWhiteWithNoEdge() throws {
        let pixels = try Self.renderedCard(in: .light)

        let fill = pixels.count(matching: Self.resolved(.white, in: .light))
        let edge = pixels.count(matching: Self.resolved(.systemGray, in: .light))

        #expect(fill >= Self.minimumFillPixels, "Only \(fill) white pixels: the pills have another fill.")
        #expect(edge < Self.minimumEdgePixels, "\(edge) systemGray pixels: the pills have an edge in light.")
    }

    /// The two capsules at the default size and scale 2 are about 2 × 70 × 30pt, so 4 × 2,000 pixels of fill.
    private static let minimumFillPixels = 3_000
    /// The edge is 1pt, 2 pixels, around both capsules: about 2 × 2 × 200pt of perimeter.
    private static let minimumEdgePixels = 300

    private static func resolved(_ color: UIColor, in style: UIUserInterfaceStyle) -> UIColor {
        color.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
    }

    private static func renderedCard(in scheme: ColorScheme) throws -> RenderedPixels {
        let renderer = ImageRenderer(content: BlockedCommentCard(
            commentID: "6894060", backgroundColor: Color(uiColor: .systemGray5), showAction: {}, unblockAction: {}
        )
        .environment(\.colorScheme, scheme)
        .environment(\.dynamicTypeSize, .large)
        .environment(\.locale, Locale(identifier: "en_US")))
        renderer.scale = 2
        return try RenderedPixels(#require(renderer.cgImage, "The card did not render."))
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
            let pixel = Array(bytes[start..<start + 4])
            guard pixel.last == 255 else { continue }
            if zip(pixel.prefix(3), target).allSatisfy({ abs(Int($0) - $1) <= 3 }) {
                count += 1
            }
        }
        return count
    }
}
