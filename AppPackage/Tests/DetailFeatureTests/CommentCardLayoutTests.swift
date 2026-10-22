import AppModels
@testable import DetailFeature
import SwiftUI
import UIKit
import XCTest

@MainActor
final class CommentCardLayoutTests: XCTestCase {
    func testShortCommentWithStackedMetadataKeepsFullRoundedBackground() throws {
        try verifyCard(author: "Comment author with a long name", text: "Short comment.", name: "stacked-short")
    }

    func testShortAuthorAndLongCommentKeepTheSameCardShape() throws {
        try verifyCard(
            author: "A", text: String(repeating: "A longer comment fills the available width. ", count: 8),
            name: "horizontal-long"
        )
    }

    private func verifyCard(author: String, text: String, name: String) throws {
        let comment = GalleryComment(
            votedUp: false, votedDown: false, votable: true, editable: false,
            score: "+283", author: author, contents: [.init(type: .plainText, text: text)],
            commentID: "card-shape", commentDate: Date(timeIntervalSince1970: 1_787_409_540)
        )
        for size in [DynamicTypeSize.large, .accessibility1, .accessibility3, .accessibility5] {
            for scheme in [ColorScheme.light, .dark] {
                let renderer = ImageRenderer(content:
                    DetailView.CommentCell(comment: comment, backgroundColor: Color(uiColor: .systemGray5))
                        .environment(\.dynamicTypeSize, size)
                        .environment(\.colorScheme, scheme)
                        .environment(\.locale, Locale(identifier: "en_US"))
                )
                renderer.scale = 2
                let image = try XCTUnwrap(renderer.cgImage)
                let attachment = XCTAttachment(image: UIImage(cgImage: image))
                attachment.name = "Comment card \(name) \(size) \(scheme)"
                attachment.lifetime = .keepAlways
                add(attachment)

                // The card background must reach every straight edge, even when its short text
                // and stacked header have a smaller intrinsic width than the allocated card.
                for point in [
                    CGPoint(x: 1, y: image.height / 2),
                    CGPoint(x: image.width - 2, y: image.height / 2),
                    CGPoint(x: image.width / 2, y: 1),
                    CGPoint(x: image.width / 2, y: image.height - 2)
                ] {
                    XCTAssertEqual(try alpha(image, point: point), 255, "\(name), \(size), \(scheme), \(point)")
                }
                for point in [
                    CGPoint(x: 0, y: 0), CGPoint(x: image.width - 1, y: 0),
                    CGPoint(x: 0, y: image.height - 1), CGPoint(x: image.width - 1, y: image.height - 1)
                ] {
                    XCTAssertEqual(try alpha(image, point: point), 0, "Rounded corner: \(name), \(size), \(scheme)")
                }
            }
        }
    }

    private func alpha(_ image: CGImage, point: CGPoint) throws -> UInt8 {
        let pixel = try XCTUnwrap(image.cropping(to: CGRect(origin: point, size: CGSize(width: 1, height: 1))))
        let context = try XCTUnwrap(CGContext(
            data: nil, width: 1, height: 1, bitsPerComponent: 8, bytesPerRow: 4,
            space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ))
        context.draw(pixel, in: CGRect(x: 0, y: 0, width: 1, height: 1))
        return try XCTUnwrap(context.data).load(fromByteOffset: 3, as: UInt8.self)
    }
}
