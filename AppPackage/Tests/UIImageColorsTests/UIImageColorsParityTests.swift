import Testing
import Foundation
import UIKit
import UIImageColors

// Wave 0 parity lock for DEP-02 (D-16, D-18). These fixtures freeze the deterministic component
// output of `UIImage.getColors(quality: .lowest)` so the later local UIImageColors module can be
// proven identical on the numbers, not on subjective appearance — final visual judgment stays with
// user verification per D-19.
//
// The fixtures are solid *neutral gray* images on purpose. A uniform fill collapses to a single
// counted color, so the algorithm's edge color becomes the background and — since no second color
// can contrast with it — primary/secondary/detail fall back to the light/dark text default. Grays
// (R == G == B) also sidestep the library's internal channel packing and any sRGB/P3 gamut
// difference, since the neutral axis is shared and channel order is symmetric. That makes the
// expected tuples stable across devices while still exercising:
//   * background parity (the dominant color is returned), and
//   * the light-vs-dark background fallback branch (light → black text, dark → white text).
@Suite
struct UIImageColorsParityTests {
    private struct RGBA: Equatable {
        let red: Int
        let green: Int
        let blue: Int
        let alpha: Int
    }

    private func solidImage(_ color: UIColor, size: CGSize = .init(width: 60, height: 60)) -> UIImage {
        UIGraphicsImageRenderer(size: size).image { context in
            color.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func components(_ color: UIColor) -> RGBA {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        return RGBA(
            red: Int((red * 255).rounded()),
            green: Int((green * 255).rounded()),
            blue: Int((blue * 255).rounded()),
            alpha: Int((alpha * 255).rounded())
        )
    }

    private func isClose(_ lhs: RGBA, _ rhs: RGBA, tolerance: Int = 2) -> Bool {
        abs(lhs.red - rhs.red) <= tolerance
            && abs(lhs.green - rhs.green) <= tolerance
            && abs(lhs.blue - rhs.blue) <= tolerance
            && lhs.alpha == rhs.alpha
    }

    private func gray(_ level: Int) -> UIColor {
        UIColor(
            red: CGFloat(level) / 255, green: CGFloat(level) / 255,
            blue: CGFloat(level) / 255, alpha: 1
        )
    }

    /// A light background returns the dominant gray and falls back to black text for every accent slot.
    @Test
    func lightSolidImageLocksBackgroundAndBlackTextFallback() throws {
        let colors = try #require(solidImage(gray(200)).getColors(quality: .lowest))

        let background = components(try #require(colors.background))
        let black = RGBA(red: 0, green: 0, blue: 0, alpha: 255)
        #expect(isClose(background, RGBA(red: 200, green: 200, blue: 200, alpha: 255)))
        #expect(components(try #require(colors.primary)) == black)
        #expect(components(try #require(colors.secondary)) == black)
        #expect(components(try #require(colors.detail)) == black)
    }

    /// A dark background returns the dominant gray and falls back to white text for every accent slot.
    @Test
    func darkSolidImageLocksBackgroundAndWhiteTextFallback() throws {
        let colors = try #require(solidImage(gray(40)).getColors(quality: .lowest))

        let background = components(try #require(colors.background))
        let white = RGBA(red: 255, green: 255, blue: 255, alpha: 255)
        #expect(isClose(background, RGBA(red: 40, green: 40, blue: 40, alpha: 255)))
        #expect(components(try #require(colors.primary)) == white)
        #expect(components(try #require(colors.secondary)) == white)
        #expect(components(try #require(colors.detail)) == white)
    }
}
