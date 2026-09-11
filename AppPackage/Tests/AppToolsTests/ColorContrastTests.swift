import AppTools
import CustomDump
import SwiftUI
import Testing

/// Pins the adaptive badge-text rule (Phase 16 D-26) at the points where it is easiest to get wrong:
/// the black/white extremes, the crossover luminance where black and white tie, one step either
/// side of it, and the worst real category variant, whose black/white ratios sit 0.07 apart.
struct ColorContrastTests {
    /// Black and white text contrast equally with a background of this relative luminance
    /// (√0.0525 − 0.05 ≈ 0.1791); both ratios are ≈ 4.583:1 there.
    private static let crossoverLuminance = 0.1791

    /// ExHentai / Game CG / light — the worst best-of variant in the 84-row audit table
    /// (`16-CONTRAST-AUDIT.md` row 59): white 4.55, black 4.62. Components are the colorset's sRGB floats.
    private static let worstVariant = Color(.sRGB, red: 0.38, green: 0.49, blue: 0.39)

    private static let linearBlack = Color.Resolved(colorSpace: .sRGBLinear, red: 0, green: 0, blue: 0)
    private static let linearWhite = Color.Resolved(colorSpace: .sRGBLinear, red: 1, green: 1, blue: 1)

    // MARK: - relativeLuminance

    /// The crossover gray's expectation is the channel `Color.Resolved` actually stores —
    /// `Float(0.1791)`, 7e-9 above the literal — so the 1e-9 tolerance is about the arithmetic, not
    /// Float storage. It still refutes the double-decode bug outright: decoding the already-linear
    /// channel again would report ≈ 0.027.
    @Test(arguments: [
        LuminanceFixture(name: "linear black", channel: 0, expectedLuminance: 0),
        LuminanceFixture(name: "linear white", channel: 1, expectedLuminance: 1),
        LuminanceFixture(name: "crossover gray", channel: 0.1791, expectedLuminance: Double(Float(0.1791)))
    ])
    private func readsTheLinearChannels(fixture: LuminanceFixture) {
        let luminance = Self.linearGray(fixture.channel).relativeLuminance

        #expect(
            abs(luminance - fixture.expectedLuminance) < 1e-9,
            "\(fixture.name): expected \(fixture.expectedLuminance), got \(luminance)"
        )
    }

    // MARK: - contrastRatio

    @Test
    func blackAndWhiteContrastAtTwentyOneToOneSymmetrically() {
        let ratio = Color.contrastRatio(Self.linearWhite, Self.linearBlack)

        #expect(abs(ratio - 21) < 1e-6)
        #expect(Color.contrastRatio(Self.linearBlack, Self.linearWhite) == ratio)
    }

    @Test
    func crossoverGrayTiesBlackAndWhite() {
        let gray = Self.linearGray(Float(Self.crossoverLuminance))

        #expect(abs(Color.contrastRatio(gray, Self.linearWhite) - 4.583) < 0.001)
        #expect(abs(Color.contrastRatio(gray, Self.linearBlack) - 4.583) < 0.001)
    }

    @Test
    func worstCategoryVariantPrefersBlackByANarrowMargin() {
        let background = Self.worstVariant.resolve(in: EnvironmentValues())

        #expect(abs(Color.contrastRatio(background, Self.linearBlack) - 4.62) < 0.01)
        #expect(abs(Color.contrastRatio(background, Self.linearWhite) - 4.55) < 0.01)
    }

    // MARK: - contrastingForeground

    /// The tie is pinned on the `Double` entry point because no `Color.Resolved` can carry exactly
    /// L = 0.1791 (its channels are `Float`); the resolved-colour fixtures below pin the neighbours.
    @Test(arguments: [
        TieFixture(name: "exactly at the crossover", luminance: 0.1791, expectedForeground: .white),
        TieFixture(name: "one ulp above the crossover", luminance: 0.1791.nextUp, expectedForeground: .black)
    ])
    private func resolvesTheTieToWhite(fixture: TieFixture) {
        let foreground = Color.contrastingForeground(forRelativeLuminance: fixture.luminance)

        expectNoDifference(foreground, fixture.expectedForeground)
    }

    @Test(arguments: [
        ForegroundFixture(name: "black background", background: .black, expectedForeground: .white),
        ForegroundFixture(name: "white background", background: .white, expectedForeground: .black),
        ForegroundFixture(
            name: "one step above the crossover",
            background: Color(.sRGBLinear, red: 0.1792, green: 0.1792, blue: 0.1792),
            expectedForeground: .black
        ),
        ForegroundFixture(
            name: "one step below the crossover",
            background: Color(.sRGBLinear, red: 0.1790, green: 0.1790, blue: 0.1790),
            expectedForeground: .white
        ),
        ForegroundFixture(name: "worst variant", background: worstVariant, expectedForeground: .black)
    ])
    private func choosesTheMoreContrastingForeground(fixture: ForegroundFixture) {
        let foreground = fixture.background.contrastingForeground(in: EnvironmentValues())

        expectNoDifference(foreground, fixture.expectedForeground)
    }

    @Test
    func staticAndInstanceRulesAgree() {
        let environment = EnvironmentValues()
        let backgrounds = [
            Color.black,
            .white,
            Self.worstVariant,
            Color(.sRGBLinear, red: 0.1791, green: 0.1791, blue: 0.1791),
            Color(.sRGBLinear, red: 0.1792, green: 0.1792, blue: 0.1792)
        ]

        for background in backgrounds {
            expectNoDifference(
                Color.contrastingForeground(on: background.resolve(in: environment)),
                background.contrastingForeground(in: environment)
            )
        }
    }

    // MARK: - composited(over:opacity:)

    @Test(arguments: [
        CompositeFixture(opacity: 0.3, expectedChannel: 0.75373),
        CompositeFixture(opacity: 1, expectedChannel: 0.1791),
        CompositeFixture(opacity: 0, expectedChannel: 1)
    ])
    private func compositesInLinearSpace(fixture: CompositeFixture) {
        let gray = Self.linearGray(Float(Self.crossoverLuminance))

        let composite = gray.composited(over: Self.linearWhite, opacity: fixture.opacity)

        for channel in [composite.linearRed, composite.linearGreen, composite.linearBlue] {
            #expect(abs(Double(channel) - fixture.expectedChannel) < 1e-6)
        }
        #expect(composite.opacity == 1)
    }

    private static func linearGray(_ channel: Float) -> Color.Resolved {
        Color.Resolved(colorSpace: .sRGBLinear, red: channel, green: channel, blue: channel)
    }
}

private struct LuminanceFixture: CustomTestStringConvertible, Sendable {
    let name: String
    let channel: Float
    let expectedLuminance: Double

    var testDescription: String { name }
}

private struct TieFixture: CustomTestStringConvertible, Sendable {
    let name: String
    let luminance: Double
    let expectedForeground: Color

    var testDescription: String { name }
}

private struct ForegroundFixture: CustomTestStringConvertible, Sendable {
    let name: String
    let background: Color
    let expectedForeground: Color

    var testDescription: String { name }
}

private struct CompositeFixture: CustomTestStringConvertible, Sendable {
    let opacity: Double
    let expectedChannel: Double

    var testDescription: String { "opacity \(opacity)" }
}
