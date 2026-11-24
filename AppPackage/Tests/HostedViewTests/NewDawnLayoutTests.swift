import AppComponents
import AppModels
import Foundation
import SwiftUI
import Testing
import UIKit

/// New Dawn draws only the sun or moon body, and its reward line is never cut.
///
/// The dark appearance drew eight rays around the disc, and one of them crossed the text (the owner's C5 item,
/// 19-13: remove the rays in light and dark and keep the body). The greeting's scroll view also ignored the bottom
/// safe area, so at the largest text size the reward line, the last line, ended under the home indicator even when
/// scrolled to the end. The scroll view now insets its content for the bottom safe area, while the backdrop still
/// bleeds to every edge.
@MainActor
struct NewDawnLayoutTests {
    /// A pixel of the sun's yellow: bright red, bright green, little blue. Both appearances' yellows are inside it.
    private static func isSunYellow(red: UInt8, green: UInt8, blue: UInt8) -> Bool {
        red >= 200 && green >= 180 && blue <= 80
    }

    /// In the dark appearance every pixel of the sun's yellow lies inside the disc, give or take one pixel.
    @Test
    func theDarkAppearanceDrawsNoRaysAroundTheSun() throws {
        let size = try HostedView.sceneSize()
        try HostedView.withRoot(of: Self.page(size: .large, scheme: .dark), size: size) { root in
            let image = try Self.pixels(of: root)
            // The view's own formula: the sun is a disc whose width is a share of the page's width.
            let sunWidth = size.width * (size.width >= 500 ? 0.5 : 0.6)
            let offset = size.width * 0.2
            let centre = CGPoint(x: size.width - sunWidth / 2 + offset, y: sunWidth / 2 - offset)
            let allowance = 1 / image.scale
            var inside = 0
            var outside = 0
            for row in 0..<image.height {
                for column in 0..<image.width {
                    let pixel = image.pixel(column: column, row: row)
                    guard Self.isSunYellow(red: pixel.red, green: pixel.green, blue: pixel.blue) else { continue }
                    let across = (CGFloat(column) + 0.5) / image.scale - centre.x
                    let down = (CGFloat(row) + 0.5) / image.scale - centre.y
                    if (across * across + down * down).squareRoot() > sunWidth / 2 + allowance {
                        outside += 1
                    } else {
                        inside += 1
                    }
                }
            }
            #expect(inside > 0, "The page shows no sun at all, so the test shows nothing.")
            #expect(outside == 0, "\(outside) pixel(s) of the sun's yellow lie outside the disc.")
        }
    }

    /// At the largest text size, scrolled to its end, the reward line lies above the bottom safe-area edge.
    @Test
    func theRewardLineEndsAboveTheBottomSafeArea() throws {
        let greeting = Greeting.mock
        let reward = try #require(greeting.gainContent)
        let size = try HostedView.sceneSize()
        try AccessibilityElements.read(
            of: Self.page(size: .accessibility5, scheme: .light, greeting: greeting), size: size
        ) { elements in
            let root = try #require(elements.first as? UIView, "The first element is not the hosted root view.")
            let scrollView = try #require(Self.scrollViews(in: root).first, "The page has no scroll view.")
            // The end of the scroll range; a greeting that fits does not scroll, and its rest position is its end.
            let insets = scrollView.adjustedContentInset
            let end = max(scrollView.contentSize.height - scrollView.bounds.height + insets.bottom, -insets.top)
            scrollView.setContentOffset(CGPoint(x: 0, y: end), animated: false)
            RunLoop.main.run(until: .now.addingTimeInterval(0.2))
            let line = try #require(
                elements.first(where: { $0.accessibilityLabel == reward }),
                "The page has no element labelled with the reward line."
            )
            let frame = try #require(root.window?.screen.coordinateSpace.convert(line.accessibilityFrame, to: root))
            let edge = root.safeAreaLayoutGuide.layoutFrame.maxY
            #expect(frame.maxY <= edge, "The reward line ends at \(frame.maxY), below the safe area's edge \(edge).")
        }
    }

    /// At the default size the greeting does not scroll: its content is no taller than the room it has.
    @Test
    func theGreetingDoesNotScrollAtTheDefaultSize() throws {
        try HostedView.withRoot(of: Self.page(size: .large, scheme: .light), size: HostedView.sceneSize()) { root in
            let scrollView = try #require(Self.scrollViews(in: root).first, "The page has no scroll view.")
            let insets = scrollView.adjustedContentInset
            let visibleHeight = scrollView.bounds.height - insets.top - insets.bottom
            #expect(
                scrollView.contentSize.height <= visibleHeight + 0.5,
                "The content is \(scrollView.contentSize.height) pt tall in \(visibleHeight) pt of room."
            )
        }
    }

    private static func page(
        size: DynamicTypeSize, scheme: ColorScheme, greeting: Greeting = .mock
    ) -> some View {
        NewDawnView(greeting: greeting)
            .environment(\.colorScheme, scheme)
            .environment(\.dynamicTypeSize, size)
            .environment(\.locale, Locale(identifier: "en_US"))
    }

    private static func scrollViews(in view: UIView) -> [UIScrollView] {
        ((view as? UIScrollView).map({ [$0] }) ?? []) + view.subviews.flatMap(scrollViews(in:))
    }

    /// The root view's drawn pixels as 8-bit RGBA.
    private static func pixels(of root: UIView) throws -> Pixels {
        let image = UIGraphicsImageRenderer(bounds: root.bounds).image { _ in
            root.drawHierarchy(in: root.bounds, afterScreenUpdates: true)
        }
        let cgImage = try #require(image.cgImage)
        let width = cgImage.width
        let height = cgImage.height
        var data = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = data.withUnsafeMutableBytes { buffer in
            guard let context = CGContext(
                data: buffer.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
            ) else { return false }
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        try #require(drawn, "The image could not be drawn into an RGBA buffer.")
        return Pixels(data: data, width: width, height: height, scale: image.scale)
    }

    private struct Pixel {
        let red: UInt8
        let green: UInt8
        let blue: UInt8
    }

    private struct Pixels {
        let data: [UInt8]
        let width: Int
        let height: Int
        let scale: CGFloat

        func pixel(column: Int, row: Int) -> Pixel {
            let offset = (row * width + column) * 4
            return Pixel(red: data[offset], green: data[offset + 1], blue: data[offset + 2])
        }
    }
}
