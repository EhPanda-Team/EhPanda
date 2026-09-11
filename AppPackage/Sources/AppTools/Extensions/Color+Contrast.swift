import SwiftUI

extension Color.Resolved {
    /// WCAG 2.x relative luminance of the resolved colour, in 0…1.
    ///
    /// `Color.Resolved` carries every channel twice: `red`/`green`/`blue` are gamma-encoded sRGB and
    /// `linearRed`/`linearGreen`/`linearBlue` are the same channels already passed through the sRGB
    /// transfer function. WCAG defines luminance on the linear channels, so this reads those directly
    /// and applies only the weights. Running the transfer function here would decode twice — the
    /// classic contrast bug, which reports a mid-gray as nearly black — and weighting the
    /// gamma-encoded channels instead would be equally wrong in the other direction.
    public var relativeLuminance: Double {
        0.2126 * Double(linearRed) + 0.7152 * Double(linearGreen) + 0.0722 * Double(linearBlue)
    }

    /// Source-over compositing of the receiver drawn at `opacity` over an opaque `backdrop`.
    ///
    /// Exists for the Filters `CategoryCell`, whose excluded state draws the category colour at
    /// 0.3 opacity over the sheet background: the text colour must be chosen against what is actually
    /// on screen — the composite — not against the raw category colour, which is far darker than
    /// the wash the eye sees.
    ///
    /// The blend runs per *linear* channel because light adds linearly; interpolating the
    /// gamma-encoded channels would darken the result and skew the luminance the composite feeds
    /// into. The receiver is treated as opaque (every category colour is), so `opacity` is the only
    /// coverage in play, and the result is returned opaque in `.sRGBLinear`.
    public func composited(over backdrop: Color.Resolved, opacity: Double) -> Color.Resolved {
        func blend(_ source: Float, over destination: Float) -> Float {
            Float(opacity * Double(source) + (1 - opacity) * Double(destination))
        }
        return Color.Resolved(
            colorSpace: .sRGBLinear,
            red: blend(linearRed, over: backdrop.linearRed),
            green: blend(linearGreen, over: backdrop.linearGreen),
            blue: blend(linearBlue, over: backdrop.linearBlue),
            opacity: 1
        )
    }
}

extension Color {
    /// The background luminance at which black and white text contrast equally.
    ///
    /// Against white the ratio is 1.05 / (L + 0.05); against black it is (L + 0.05) / 0.05. They are
    /// equal when (L + 0.05)² = 1.05 × 0.05 = 0.0525, i.e. L = √0.0525 − 0.05 ≈ 0.1791, where both are
    /// ≈ 4.583:1. White wins below it, black above it.
    private static let foregroundCrossoverLuminance = 0.1791

    /// WCAG 2.x contrast ratio between two resolved colours, always ≥ 1 regardless of argument order.
    public static func contrastRatio(_ lhs: Color.Resolved, _ rhs: Color.Resolved) -> Double {
        let lighter = max(lhs.relativeLuminance, rhs.relativeLuminance)
        let darker = min(lhs.relativeLuminance, rhs.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }

    /// Black or white, whichever contrasts more with a background of relative luminance `luminance`
    /// (Phase 16 D-26).
    ///
    /// The category backgrounds are frozen brand colours, so legibility has to come from the text.
    /// This is the *better-of* rule: black when the background's luminance is strictly above the
    /// crossover, white at or below it. Because the two ratios cross at ≈ 4.583:1, the chosen text
    /// is never below 4.58:1 on *any* background — a structural floor no future colour can break.
    /// The alternative "white unless it fails 4.5:1" was rejected: its floor is only 4.5, and it
    /// flips a different set of badges (45 instead of 47), contradicting D-26's measured numbers.
    ///
    /// The rule is a property of the luminance alone, which is why it is exposed on a `Double`:
    /// `Color.Resolved` stores its channels as `Float`, so the exact crossover cannot be represented
    /// through a resolved colour (`Float(0.1791)` rounds up by 7e-9 and lands strictly above it).
    /// This is the seam where the tie — white at exactly the crossover, black one step above — is
    /// exactly testable; the colour-taking overloads below all route through it.
    public static func contrastingForeground(forRelativeLuminance luminance: Double) -> Color {
        luminance > foregroundCrossoverLuminance ? .black : .white
    }

    /// `contrastingForeground(forRelativeLuminance:)` for the luminance of `background`.
    public static func contrastingForeground(on background: Color.Resolved) -> Color {
        contrastingForeground(forRelativeLuminance: background.relativeLuminance)
    }

    /// `contrastingForeground(on:)` for this colour resolved in `environment`.
    ///
    /// Resolving through the environment is what makes the choice follow the asset catalog's
    /// light/dark and Increase Contrast variants: the same `Color` resolves to a different
    /// `Color.Resolved` under each, and the text colour follows automatically.
    public func contrastingForeground(in environment: EnvironmentValues) -> Color {
        Self.contrastingForeground(on: resolve(in: environment))
    }
}
