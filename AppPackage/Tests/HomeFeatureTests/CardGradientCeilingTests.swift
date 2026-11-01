import Foundation
@testable import HomeFeature
import SwiftUI
import Testing

struct CardGradientCeilingTests {
    @MainActor
    @Test(arguments: [ColorSchemeContrast.standard, .increased])
    func limitedColorsKeepCardTextReadable(_ contrast: ColorSchemeContrast) {
        let text = CardText(.dark, contrast)
        let ceiling = CardGradientCeiling(contrast)
        let colors = Color.Resolved.brightCoverColors + Color.Resolved.darkCoverColors
            + Color.Resolved.grays + Color.Resolved.gamutSurface
        for color in colors {
            #expect(isReadable(text, contrast, over: ceiling.limit(color)))
        }
    }

    /// ColorfulX's blends take hues the palette does not contain, so the guarantee needs every hue
    /// at the ceiling to be readable.
    @MainActor
    @Test(arguments: [ColorSchemeContrast.standard, .increased])
    func everyHueAtTheCeilingIsReadable(_ contrast: ColorSchemeContrast) {
        let text = CardText(.dark, contrast)
        let ceiling = CardGradientCeiling(contrast)
        for color in Color.Resolved.gamutSurface where lightness(of: color) > ceiling.lightness {
            #expect(isReadable(text, contrast, over: dimmed(color, toLightness: ceiling.lightness)))
        }
    }

    /// Saturated blue binds the ceiling, so blue just above it must fail; this keeps the ceiling from
    /// drifting needlessly dark.
    @MainActor
    @Test(arguments: [ColorSchemeContrast.standard, .increased])
    func ceilingHasNoSlack(_ contrast: ColorSchemeContrast) {
        let ceiling = CardGradientCeiling(contrast)
        let blue = dimmed(Color.Resolved(hex: 0x0000FF), toLightness: ceiling.lightness + 0.05)
        #expect(!isReadable(CardText(.dark, contrast), contrast, over: blue))
    }

    @Test(arguments: [CardGradientCeiling.standard, .increased])
    func colorsBelowTheKneeAreUnchanged(_ ceiling: CardGradientCeiling) {
        for color in Color.Resolved.darkCoverColors {
            #expect(ceiling.limit(color) == color)
        }
    }

    @Test(arguments: [CardGradientCeiling.standard, .increased])
    func whiteLandsExactlyOnTheCeiling(_ ceiling: CardGradientCeiling) {
        let expected = luminance(ofLightness: ceiling.lightness)
        #expect(abs(ceiling.limit(Color.Resolved(hex: 0xFFFFFF)).relativeLuminance - expected) < 1e-5)
    }

    /// Near L* 100 the curve is almost flat, so neighboring light grays may tie within `Float` rounding.
    @Test(arguments: [CardGradientCeiling.standard, .increased])
    func limitKeepsTheLightnessOrder(_ ceiling: CardGradientCeiling) {
        let limited = Color.Resolved.grays.map({ ceiling.limit($0).relativeLuminance })
        for (darker, lighter) in zip(limited, limited.dropFirst()) {
            #expect(darker - lighter < 1e-6)
        }
    }

    /// Dimming scales linear light, so each limited color keeps its chromaticity: hue and purity.
    @Test(arguments: [CardGradientCeiling.standard, .increased])
    func limitKeepsHueAndPurity(_ ceiling: CardGradientCeiling) {
        for color in Color.Resolved.brightCoverColors {
            let limited = ceiling.limit(color)
            let scale = limited.relativeLuminance / color.relativeLuminance
            #expect(abs(Double(limited.linearRed) - Double(color.linearRed) * scale) < 1e-5)
            #expect(abs(Double(limited.linearGreen) - Double(color.linearGreen) * scale) < 1e-5)
            #expect(abs(Double(limited.linearBlue) - Double(color.linearBlue) * scale) < 1e-5)
        }
    }
}

/// White text keeps 4.5:1; secondary text keeps 3:1, or 4.5:1 under Increase Contrast.
private func isReadable(_ text: CardText, _ contrast: ColorSchemeContrast, over background: Color.Resolved) -> Bool {
    text.primary.contrastRatio(over: background) >= 4.5
        && text.secondary.contrastRatio(over: background) >= (contrast == .increased ? 4.5 : 3)
}

private func luminance(ofLightness lightness: Double) -> Double {
    pow((lightness + 16) / 116, 3)
}

private func lightness(of color: Color.Resolved) -> Double {
    116 * cbrt(color.relativeLuminance) - 16
}

/// Scales linear light down to `lightness`, the way `CardGradientCeiling` dims a color.
private func dimmed(_ color: Color.Resolved, toLightness lightness: Double) -> Color.Resolved {
    let scale = Float(luminance(ofLightness: lightness) / color.relativeLuminance)
    return Color.Resolved(
        colorSpace: .sRGBLinear,
        red: color.linearRed * scale,
        green: color.linearGreen * scale,
        blue: color.linearBlue * scale
    )
}
