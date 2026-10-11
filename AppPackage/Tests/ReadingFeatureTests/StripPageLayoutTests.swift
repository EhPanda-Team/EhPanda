import CoreGraphics
@testable import ReadingFeature
import Testing

/// The height an unloaded page of the vertical strip takes (`StripPageLayout`), at the widths of the iPhones (three
/// pixels per point) and iPads (two) the reader runs on, portrait and landscape.
@Suite
struct StripPageLayoutTests {
    struct WidthCase: CustomTestStringConvertible {
        let width: CGFloat
        let displayScale: CGFloat
        var testDescription: String { "\(width) pt at \(displayScale)x" }
    }

    static let widthCases = [393, 402, 420, 440, 852, 874, 912, 956].map({ WidthCase(width: $0, displayScale: 3) })
        + [744, 820, 834, 1024, 1133, 1180, 1210, 1366].map({ WidthCase(width: $0, displayScale: 2) })

    /// The height is a whole number of pixels within half a pixel of the exact height at the 7:10 aspect ratio. A
    /// thousandth of a pixel covers the binary representation of a third of a point.
    @Test(arguments: widthCases)
    func heightIsTheNearestPixelRow(widthCase: WidthCase) {
        let height = StripPageLayout.height(
            width: widthCase.width, aspectRatio: 7 / 10, displayScale: widthCase.displayScale
        )
        let pixels = height * widthCase.displayScale
        let exactPixels = widthCase.width / (7 / 10) * widthCase.displayScale
        #expect(abs(pixels - pixels.rounded()) < 0.001)
        #expect(abs(pixels - exactPixels) <= 0.5)
    }
}
