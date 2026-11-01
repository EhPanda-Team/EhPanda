import Foundation
@testable import HomeFeature
import SwiftUI
import Testing
import UIKit

struct CardGradientCeilingTests {
    /// Bright colors real cover palettes produced (the white fallback among them), and the sRGB primaries.
    private static let brightColors: [Color.Resolved] = [
        0xFFFFFF, 0x00E4FF, 0xFCA89E, 0xDED2BC, 0xBFC1E1, 0xFF6597, 0xEE425F, 0x03B2FC,
        0xFF0000, 0x00FF00, 0x0000FF, 0xFFFF00, 0x00FFFF, 0xFF00FF
    ].map(resolved)

    /// Dark colors real cover palettes produced, all below the knee of both ceilings.
    private static let darkColors: [Color.Resolved] = [0x000000, 0x060606, 0x180B19, 0x312C29].map(resolved)

    private static let grays: [Color.Resolved] = stride(from: 0, through: 255, by: 5).map({ resolved(0x010101 * $0) })

    /// The outer surface of the sRGB cube in steps of 1/8: every hue at full and partial saturation.
    private static let gamutSurface: [Color.Resolved] = {
        let steps = (0...8).map({ Float($0) / 8 })
        return steps.flatMap { red in
            steps.flatMap { green in
                steps.compactMap { blue in
                    max(red, green, blue) == 1 ? Color.Resolved(red: red, green: green, blue: blue) : nil
                }
            }
        }
    }()

    @MainActor
    @Test(arguments: [ColorSchemeContrast.standard, .increased])
    func limitedColorsKeepCardTextReadable(_ contrast: ColorSchemeContrast) {
        let text = CardText(contrast)
        let ceiling = CardGradientCeiling(contrast)
        for color in Self.brightColors + Self.darkColors + Self.grays + Self.gamutSurface {
            #expect(text.isReadable(over: ceiling.limit(color)))
        }
    }

    /// ColorfulX's blends take hues the palette does not contain, so the guarantee needs every hue
    /// at the ceiling to be readable.
    @MainActor
    @Test(arguments: [ColorSchemeContrast.standard, .increased])
    func everyHueAtTheCeilingIsReadable(_ contrast: ColorSchemeContrast) {
        let text = CardText(contrast)
        let ceiling = CardGradientCeiling(contrast)
        for color in Self.gamutSurface where lightness(of: color) > ceiling.lightness {
            #expect(text.isReadable(over: dimmed(color, toLightness: ceiling.lightness)))
        }
    }

    /// Saturated blue binds the ceiling, so blue just above it must fail; this keeps the ceiling from
    /// drifting needlessly dark.
    @MainActor
    @Test(arguments: [ColorSchemeContrast.standard, .increased])
    func ceilingHasNoSlack(_ contrast: ColorSchemeContrast) {
        let ceiling = CardGradientCeiling(contrast)
        let blue = dimmed(resolved(0x0000FF), toLightness: ceiling.lightness + 0.05)
        #expect(!CardText(contrast).isReadable(over: blue))
    }

    @Test(arguments: [CardGradientCeiling.standard, .increased])
    func colorsBelowTheKneeAreUnchanged(_ ceiling: CardGradientCeiling) {
        for color in Self.darkColors {
            #expect(ceiling.limit(color) == color)
        }
    }

    @Test(arguments: [CardGradientCeiling.standard, .increased])
    func whiteLandsExactlyOnTheCeiling(_ ceiling: CardGradientCeiling) {
        let expected = luminance(ofLightness: ceiling.lightness)
        #expect(abs(luminance(of: ceiling.limit(resolved(0xFFFFFF))) - expected) < 1e-5)
    }

    /// Near L* 100 the curve is almost flat, so neighboring light grays may tie within `Float` rounding.
    @Test(arguments: [CardGradientCeiling.standard, .increased])
    func limitKeepsTheLightnessOrder(_ ceiling: CardGradientCeiling) {
        let limited = Self.grays.map({ luminance(of: ceiling.limit($0)) })
        for (darker, lighter) in zip(limited, limited.dropFirst()) {
            #expect(darker - lighter < 1e-6)
        }
    }

    /// Dimming scales linear light, so each limited color keeps its chromaticity: hue and purity.
    @Test(arguments: [CardGradientCeiling.standard, .increased])
    func limitKeepsHueAndPurity(_ ceiling: CardGradientCeiling) {
        for color in Self.brightColors {
            let limited = ceiling.limit(color)
            let scale = luminance(of: limited) / luminance(of: color)
            #expect(abs(Double(limited.linearRed) - Double(color.linearRed) * scale) < 1e-5)
            #expect(abs(Double(limited.linearGreen) - Double(color.linearGreen) * scale) < 1e-5)
            #expect(abs(Double(limited.linearBlue) - Double(color.linearBlue) * scale) < 1e-5)
        }
    }
}

/// The card's dark-mode text: SwiftUI's `.primary` and `.secondary` render as UIKit's label and
/// secondaryLabel, and Increase Contrast both makes secondaryLabel more opaque and raises its target.
private struct CardText {
    let primary: Color.Resolved
    let secondary: Color.Resolved
    let secondaryTarget: Double

    @MainActor
    init(_ contrast: ColorSchemeContrast) {
        let traits = UITraitCollection { traits in
            traits.userInterfaceStyle = .dark
            traits.accessibilityContrast = contrast == .increased ? .high : .normal
        }
        primary = resolved(UIColor.label.resolvedColor(with: traits))
        secondary = resolved(UIColor.secondaryLabel.resolvedColor(with: traits))
        secondaryTarget = contrast == .increased ? 4.5 : 3
    }

    func isReadable(over background: Color.Resolved) -> Bool {
        contrastRatio(of: primary, over: background) >= 4.5
            && contrastRatio(of: secondary, over: background) >= secondaryTarget
    }
}

private func resolved(_ hex: Int) -> Color.Resolved {
    Color.Resolved(
        red: Float((hex >> 16) & 0xFF) / 255,
        green: Float((hex >> 8) & 0xFF) / 255,
        blue: Float(hex & 0xFF) / 255
    )
}

private func resolved(_ color: UIColor) -> Color.Resolved {
    Color(uiColor: color).resolve(in: EnvironmentValues())
}

private func luminance(of color: Color.Resolved) -> Double {
    Double(0.2126 * color.linearRed + 0.7152 * color.linearGreen + 0.0722 * color.linearBlue)
}

private func luminance(ofLightness lightness: Double) -> Double {
    pow((lightness + 16) / 116, 3)
}

private func lightness(of color: Color.Resolved) -> Double {
    116 * cbrt(luminance(of: color)) - 16
}

/// Scales linear light down to `lightness`, the way `CardGradientCeiling` dims a color.
private func dimmed(_ color: Color.Resolved, toLightness lightness: Double) -> Color.Resolved {
    let scale = Float(luminance(ofLightness: lightness) / luminance(of: color))
    return Color.Resolved(
        colorSpace: .sRGBLinear,
        red: color.linearRed * scale,
        green: color.linearGreen * scale,
        blue: color.linearBlue * scale
    )
}

/// WCAG contrast of `foreground`, composited over `background` the way a translucent label is drawn.
private func contrastRatio(of foreground: Color.Resolved, over background: Color.Resolved) -> Double {
    let alpha = foreground.opacity
    let text = Color.Resolved(
        red: foreground.red * alpha + background.red * (1 - alpha),
        green: foreground.green * alpha + background.green * (1 - alpha),
        blue: foreground.blue * alpha + background.blue * (1 - alpha)
    )
    let lighter = max(luminance(of: text), luminance(of: background))
    let darker = min(luminance(of: text), luminance(of: background))
    return (lighter + 0.05) / (darker + 0.05)
}
