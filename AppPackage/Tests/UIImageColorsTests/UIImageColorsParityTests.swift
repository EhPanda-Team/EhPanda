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

    private func stripedImage(
        background: UIColor,
        stripes: [(color: UIColor, height: CGFloat)],
        size: CGSize = .init(width: 60, height: 60)
    ) -> UIImage {
        let format = UIGraphicsImageRendererFormat.preferred()
        format.opaque = true
        format.preferredRange = .standard
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            background.setFill()
            context.fill(CGRect(origin: .zero, size: size))
            var originY: CGFloat = 0
            for stripe in stripes {
                stripe.color.setFill()
                context.fill(CGRect(x: 0, y: originY, width: size.width, height: stripe.height))
                originY += stripe.height
            }
        }
    }

    private func srgb(_ red: Int, _ green: Int, _ blue: Int) -> UIColor {
        UIColor(
            red: CGFloat(red) / 255, green: CGFloat(green) / 255,
            blue: CGFloat(blue) / 255, alpha: 1
        )
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

    /// Unlike the solid-gray fixtures above (which collapse to a single color and force the
    /// black/white text fallback), this fixture is a light non-gray background overlaid with three
    /// full-width, decreasing-height stripes of saturated red/green/blue. The stripes survive the
    /// `with(minSaturation:)` filter, contrast with the background, and are mutually distinct, so
    /// `getColors` fills primary/secondary/detail with *real* accent colors instead of falling back.
    /// The decreasing heights fix the counted order, so the accent slots land deterministically:
    /// primary → red, secondary → green, detail → blue. This locks the reimplemented accent path
    /// (`with(minSaturation:)`, `isDistinct`, `isContrasting`, `accentColors`); the tuples are
    /// characterized from the current correct implementation and asserted verbatim (D-16), so a
    /// later engine/refactor change cannot silently drift them.
    @Test
    func saturatedMultiRegionImageLocksAccentColors() throws {
        let image = stripedImage(
            background: srgb(210, 180, 150),
            stripes: [
                (srgb(150, 20, 20), 15),
                (srgb(20, 120, 40), 12),
                (srgb(30, 40, 150), 9)
            ]
        )
        let colors = try #require(image.getColors(quality: .lowest))

        let background = components(try #require(colors.background))
        let primary = components(try #require(colors.primary))
        let secondary = components(try #require(colors.secondary))
        let detail = components(try #require(colors.detail))

        #expect(isClose(background, RGBA(red: 210, green: 180, blue: 150, alpha: 255)))
        #expect(isClose(primary, RGBA(red: 150, green: 20, blue: 20, alpha: 255)))
        #expect(isClose(secondary, RGBA(red: 20, green: 120, blue: 40, alpha: 255)))
        #expect(isClose(detail, RGBA(red: 30, green: 40, blue: 150, alpha: 255)))

        // Guard the finding's intent: none of the accent slots collapsed to the black/white fallback.
        let black = RGBA(red: 0, green: 0, blue: 0, alpha: 255)
        let white = RGBA(red: 255, green: 255, blue: 255, alpha: 255)
        for accent in [primary, secondary, detail] {
            #expect(accent != black)
            #expect(accent != white)
        }
    }
}
