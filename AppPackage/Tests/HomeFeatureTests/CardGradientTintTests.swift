import Foundation
@testable import HomeFeature
import SwiftUI
import Testing

struct CardGradientTintTests {
    private static let tint = CardGradientTint.standard

    private static let samples = Color.Resolved.brightCoverColors + Color.Resolved.darkCoverColors
        + Color.Resolved.grays + Color.Resolved.gamutSurface

    /// The gray fallback as drawn on the white light-mode page.
    private static let grayCard: Color.Resolved = {
        let gray = Color.homeCardFallback.resolve(in: EnvironmentValues())
        let blend = { (component: Float) in component * gray.opacity + (1 - gray.opacity) }
        return Color.Resolved(red: blend(gray.red), green: blend(gray.green), blue: blend(gray.blue))
    }()

    @Test
    func okLabMatchesItsReferenceValues() {
        let red = OKLab(Color.Resolved(hex: 0xFF0000))
        #expect(abs(red.lightness - 0.627_955) < 1e-4)
        #expect(abs(red.greenRed - 0.224_863) < 1e-4)
        #expect(abs(red.blueYellow - 0.125_846) < 1e-4)
        let white = OKLab(Color.Resolved(hex: 0xFFFFFF))
        #expect(abs(white.lightness - 1) < 1e-4 && abs(white.greenRed) < 1e-4 && abs(white.blueYellow) < 1e-4)
        let roundTrip = OKLab(OKLab(lightness: 0.6, greenRed: -0.05, blueYellow: 0.08).resolved(opacity: 1))
        #expect(abs(roundTrip.lightness - 0.6) < 1e-5)
        #expect(abs(roundTrip.greenRed + 0.05) < 1e-5)
        #expect(abs(roundTrip.blueYellow - 0.08) < 1e-5)
    }

    /// Chroma is paid for with lightness, so every tint sits as far from the white page as the gray card.
    @Test
    func tintsKeepTheGrayCardsWeight() {
        let grayCard = OKLab(Self.grayCard)
        let expected = 1 - grayCard.lightness
        for color in Self.samples {
            let tinted = OKLab(Self.tint.tint(color))
            let distance = hypot(1 - tinted.lightness, chroma(of: tinted))
            #expect(abs(distance - expected) < 1e-4)
        }
    }

    @Test
    func chromaStaysUnderTheCeiling() {
        for color in Self.samples {
            #expect(chroma(of: OKLab(Self.tint.tint(color))) <= Self.tint.chroma + 1e-5)
        }
    }

    @Test
    func colorsNearGrayKeepTheirChroma() {
        for hue in stride(from: 0.0, to: 2 * Double.pi, by: Double.pi / 6) {
            let nearGray = OKLab(lightness: 0.5, greenRed: 0.003 * cos(hue), blueYellow: 0.003 * sin(hue))
            #expect(abs(chroma(of: OKLab(Self.tint.tint(nearGray.resolved(opacity: 1)))) - 0.003) < 1e-4)
        }
    }

    @Test
    func tintsKeepTheirHue() {
        for color in Color.Resolved.gamutSurface where chroma(of: OKLab(color)) > 0.01 {
            let original = OKLab(color)
            let tinted = OKLab(Self.tint.tint(color))
            let turn = atan2(tinted.blueYellow, tinted.greenRed) - atan2(original.blueYellow, original.greenRed)
            #expect(abs(remainder(turn, 2 * Double.pi)) < 1e-3)
        }
    }

    @Test
    func neutralsLandOnANeutralGrayOfTheCardsWeight() {
        let expected = OKLab(Self.grayCard).lightness
        for gray in Color.Resolved.grays {
            let tinted = OKLab(Self.tint.tint(gray))
            #expect(chroma(of: tinted) < 1e-4)
            #expect(abs(tinted.lightness - expected) < 1e-3)
        }
    }

    @Test
    func tintsStayInsideTheGamut() {
        for color in Self.samples {
            let tinted = Self.tint.tint(color)
            for component in [tinted.linearRed, tinted.linearGreen, tinted.linearBlue] {
                #expect((0...1).contains(component))
            }
        }
    }

    /// Light blues leave the gamut before the ceiling, so pure blue keeps less chroma: the most whose
    /// color still fits, which puts one of its components on the gamut's edge.
    @Test
    func outOfGamutHuesKeepTheMostChromaThatFits() {
        let blue = OKLab(Self.tint.tint(Color.Resolved(hex: 0x0000FF)))
        #expect(chroma(of: blue) < Self.tint.chroma - 1e-3)
        #expect(blue.linear.max() > 1 - 1e-4)
    }

    @Test
    func tintsKeepTheirOpacity() {
        let clear = Color.Resolved(red: 0, green: 0, blue: 0, opacity: 0)
        #expect(Self.tint.tint(clear).opacity == 0)
    }

    /// The tint replaces the gray card at its OKLab weight, and WCAG luminance follows OKLab lightness
    /// closely at this chroma: over every hue and chroma up to the ceiling, contrast drops by at most
    /// 0.15%, near chroma 0.009, since more chroma also makes the tint lighter.
    @MainActor
    @Test(arguments: [ColorSchemeContrast.standard, .increased])
    func cardTextKeepsTheGrayCardsContrast(_ contrast: ColorSchemeContrast) {
        let text = CardText(.light, contrast)
        let primary = text.primary.contrastRatio(over: Self.grayCard)
        let secondary = text.secondary.contrastRatio(over: Self.grayCard)
        for color in Self.samples {
            let tinted = Self.tint.tint(color)
            #expect(text.primary.contrastRatio(over: tinted) >= primary * 0.998)
            #expect(text.secondary.contrastRatio(over: tinted) >= secondary * 0.998)
        }
    }
}

private func chroma(of color: OKLab) -> Double {
    hypot(color.greenRed, color.blueYellow)
}
