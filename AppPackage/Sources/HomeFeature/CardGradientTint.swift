import Foundation
import SwiftUI

/// Tints the light-mode Home card with its cover's hues while keeping the visual weight of the gray
/// card it replaces.
///
/// Against the pale light-mode page, the dark-mode gradient would make the focused card the loudest
/// element on Home. Each palette color keeps its hue, but chroma beyond half the ceiling is compressed
/// onto it (colors already near gray are left alone), and its lightness is then set so it sits exactly
/// as far from the white page, in OKLab, as the gray fallback does. Chroma is paid for with lightness,
/// so every tint carries the fallback's weight, and neutral colors land on a neutral gray of that same
/// weight. Light reds, blues and purples leave the sRGB gamut before the ceiling, so a tint keeps the
/// most chroma that fits at that weight. WCAG luminance follows OKLab lightness closely at this chroma,
/// so the card's text keeps the fallback's contrast to within 0.2%.
struct CardGradientTint {
    /// The highest OKLCH chroma a tint keeps.
    let chroma: Double

    /// The owner's pick (option 2a, 2026-11-01), made in the simulator after trying the palest of the
    /// rendered options, 2f (0.008).
    static let standard = Self(chroma: 0.035)

    /// A bound on the OKLCH chroma of sRGB colors; saturated blue peaks just under it.
    private static let maximumChroma = 0.33

    /// The gray fallback's OKLab distance from the white page it is drawn on.
    private static let pageDistance: Double = {
        let gray = Color.homeCardFallback.resolve(in: EnvironmentValues())
        let blend = { (component: Float) in component * gray.opacity + (1 - gray.opacity) }
        let card = Color.Resolved(red: blend(gray.red), green: blend(gray.green), blue: blend(gray.blue))
        return 1 - OKLab(card).lightness
    }()

    func tint(_ color: Color.Resolved) -> Color.Resolved {
        let lab = OKLab(color)
        let hue = atan2(lab.blueYellow, lab.greenRed)
        let ceiling = SoftCeiling(knee: chroma / 2, ceiling: chroma, domain: Self.maximumChroma)
        let limited = ceiling(hypot(lab.greenRed, lab.blueYellow))
        return Self.weighted(chroma: Self.largestChromaInGamut(upTo: limited, hue: hue), hue: hue)
            .resolved(opacity: color.opacity)
    }

    /// The color of `chroma` and `hue` (in radians) that sits as far from the white page as the gray
    /// fallback.
    private static func weighted(chroma: Double, hue: Double) -> OKLab {
        OKLab(
            lightness: 1 - sqrt(pageDistance * pageDistance - chroma * chroma),
            greenRed: chroma * cos(hue),
            blueYellow: chroma * sin(hue)
        )
    }

    /// Bisects for the most chroma, up to `limit`, whose weighted color fits the sRGB gamut. Gray fits,
    /// and along the weight curve a hue leaves the gamut once, near chroma 0.029 at the earliest.
    private static func largestChromaInGamut(upTo limit: Double, hue: Double) -> Double {
        guard !weighted(chroma: limit, hue: hue).isInGamut else { return limit }
        var fitting = 0.0
        var leaving = limit
        for _ in 0..<32 {
            let middle = (fitting + leaving) / 2
            if weighted(chroma: middle, hue: hue).isInGamut {
                fitting = middle
            } else {
                leaving = middle
            }
        }
        return fitting
    }
}

/// A color in Björn Ottosson's OKLab, converted from and to linear sRGB.
struct OKLab {
    let lightness: Double
    /// The a axis: negative toward green, positive toward red.
    let greenRed: Double
    /// The b axis: negative toward blue, positive toward yellow.
    let blueYellow: Double

    init(lightness: Double, greenRed: Double, blueYellow: Double) {
        self.lightness = lightness
        self.greenRed = greenRed
        self.blueYellow = blueYellow
    }

    init(_ color: Color.Resolved) {
        let red = Double(color.linearRed), green = Double(color.linearGreen), blue = Double(color.linearBlue)
        let long = cbrt(0.4122214708 * red + 0.5363325363 * green + 0.0514459929 * blue)
        let medium = cbrt(0.2119034982 * red + 0.6806995451 * green + 0.1073969566 * blue)
        let short = cbrt(0.0883024619 * red + 0.2817188376 * green + 0.6299787005 * blue)
        lightness = 0.2104542553 * long + 0.7936177850 * medium - 0.0040720468 * short
        greenRed = 1.9779984951 * long - 2.4285922050 * medium + 0.4505937099 * short
        blueYellow = 0.0259040371 * long + 0.7827717662 * medium - 0.8086757660 * short
    }

    /// The linear sRGB red, green and blue components, which leave 0...1 outside the gamut.
    var linear: SIMD3<Double> {
        let long = pow(lightness + 0.3963377774 * greenRed + 0.2158037573 * blueYellow, 3)
        let medium = pow(lightness - 0.1055613458 * greenRed - 0.0638541728 * blueYellow, 3)
        let short = pow(lightness - 0.0894841775 * greenRed - 1.2914855480 * blueYellow, 3)
        return SIMD3(
            4.0767416621 * long - 3.3077115913 * medium + 0.2309699292 * short,
            -1.2684380046 * long + 2.6097574011 * medium - 0.3413193965 * short,
            -0.0041960863 * long - 0.7034186147 * medium + 1.7076147010 * short
        )
    }

    var isInGamut: Bool {
        let components = linear
        return components.min() >= 0 && components.max() <= 1
    }

    func resolved(opacity: Float) -> Color.Resolved {
        let components = SIMD3<Float>(linear)
        return Color.Resolved(
            colorSpace: .sRGBLinear,
            red: components.x,
            green: components.y,
            blue: components.z,
            opacity: opacity
        )
    }
}
