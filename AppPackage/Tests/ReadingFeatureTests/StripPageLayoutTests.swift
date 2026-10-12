import AppModels
import CoreGraphics
@testable import ReadingFeature
import Testing

/// The height a page of the vertical strip takes before its image loads and after (`StripPageLayout`), at the widths
/// of the iPhones (three pixels per point) and iPads (two) the reader runs on, portrait and landscape, for pages of no
/// known size and of the sizes galleries serve.
@Suite
struct StripPageLayoutTests {
    struct WidthCase: CustomTestStringConvertible {
        let width: CGFloat
        let displayScale: CGFloat
        var testDescription: String { "\(width) pt at \(displayScale)x" }
    }

    struct PageCase: CustomTestStringConvertible {
        /// The page's size in pixels, `nil` for a page of no known size.
        let pixels: (width: Int, height: Int)?
        var testDescription: String {
            pixels.map({ "\($0.width) x \($0.height) px" }) ?? "no known size"
        }

        /// The page's height over its width: 7:10 for a page of no known size.
        var heightOverWidth: CGFloat {
            pixels.map({ CGFloat($0.height) / CGFloat($0.width) }) ?? 1 / (7 / 10)
        }
    }

    static let widthCases = [393, 402, 420, 440, 852, 874, 912, 956].map({ WidthCase(width: $0, displayScale: 3) })
        + [744, 820, 834, 1024, 1133, 1180, 1210, 1366].map({ WidthCase(width: $0, displayScale: 2) })

    /// No known size, a resampled page, its original, a 2:3 page, a spread wider than tall, and a strip four times as
    /// tall as wide.
    static let pageCases: [PageCase] = [nil, (1280, 1791), (1813, 2537), (1280, 1920), (2560, 1440), (800, 3200)]
        .map({ PageCase(pixels: $0) })

    /// The height is a whole number of pixels within half a pixel of the page's exact height at the width. A
    /// thousandth of a pixel covers the binary representation of a third of a point.
    @Test(arguments: widthCases, pageCases)
    func heightIsTheNearestPixelRow(widthCase: WidthCase, pageCase: PageCase) throws {
        let pageSize = try pageCase.pixels.map({ try #require(PagePixelSize(width: $0.width, height: $0.height)) })
        let height = StripPageLayout.height(
            width: widthCase.width, pageSize: pageSize, displayScale: widthCase.displayScale
        )
        let pixels = height * widthCase.displayScale
        let exactPixels = widthCase.width * pageCase.heightOverWidth * widthCase.displayScale
        #expect(abs(pixels - pixels.rounded()) < 0.001)
        #expect(abs(pixels - exactPixels) <= 0.5)
    }
}
