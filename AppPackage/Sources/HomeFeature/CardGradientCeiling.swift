import Foundation
import SwiftUI

/// Holds the dark-mode Home card gradient under a lightness ceiling, so the white title and the
/// translucent secondary text stay readable wherever the gradient's moving speckles drift.
///
/// `ImageColors` returns a background plus three colors picked to *contrast* with it, so every
/// palette carries both sides: a dark cover yields light accents (white when none qualifies), and a
/// light cover yields a light background. Nearly every card therefore has a bright speckle, and
/// white text over it fell as low as 1:1.
///
/// ColorfulX blends the speckles as a weighted average in CIE L\*a\*b\*, so no point of the gradient
/// is lighter than the palette's lightest color. Holding each palette color under the ceiling holds
/// the whole card under it, in every arrangement the animation reaches. Blends take hues the palette
/// does not contain, so the ceiling is set where every hue at or below it is readable, not just gray.
///
/// Each color is dimmed on its own rather than under one scrim for the card: a single scrim has to
/// be as dark as the brightest color needs, which also darkens the colors that were already
/// readable. Dimming scales linear light, the same thing a black scrim does to a color, so hue and
/// purity are kept and the result stays inside the sRGB gamut.
struct CardGradientCeiling {
    /// The highest CIE L\* a palette color keeps.
    let lightness: Double

    /// White text keeps 4.5:1 and secondary-label text 3:1 (the contrast the light-mode gray card gives
    /// the same text) over every sRGB color at or below this lightness. Saturated blue is the binding
    /// case: a translucent label takes almost no luminance from it, so a neutral gray could go to L\* 41.
    static let standard = Self(lightness: 32.2)

    /// Increase Contrast: the secondary label turns more opaque and keeps 4.5:1 over every sRGB color
    /// at or below this lightness, saturated blue again being the binding case.
    static let increased = Self(lightness: 27.1)

    init(lightness: Double) {
        self.lightness = lightness
    }

    init(_ contrast: ColorSchemeContrast) {
        self = contrast == .increased ? .increased : .standard
    }

    /// Colors at or below 70% of the ceiling keep their lightness; L\* 100 lands exactly on it.
    private var curve: SoftCeiling {
        SoftCeiling(knee: lightness * 0.7, ceiling: lightness, domain: 100)
    }

    func limit(_ color: Color.Resolved) -> Color.Resolved {
        let luminance = Double(0.2126 * color.linearRed + 0.7152 * color.linearGreen + 0.0722 * color.linearBlue)
        let current = Self.lightness(ofLuminance: luminance)
        let limited = curve(current)
        guard limited < current else { return color }
        let scale = Float(Self.luminance(ofLightness: limited) / luminance)
        return Color.Resolved(
            colorSpace: .sRGBLinear,
            red: color.linearRed * scale,
            green: color.linearGreen * scale,
            blue: color.linearBlue * scale,
            opacity: color.opacity
        )
    }

    /// CIE L\* of a relative luminance, with white at 1.
    private static func lightness(ofLuminance luminance: Double) -> Double {
        luminance > 216 / 24_389 ? 116 * cbrt(luminance) - 16 : luminance * 24_389 / 27
    }

    private static func luminance(ofLightness lightness: Double) -> Double {
        lightness > 8 ? pow((lightness + 16) / 116, 3) : lightness * 27 / 24_389
    }
}
