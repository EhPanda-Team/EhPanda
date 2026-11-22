import AppModels
import SwiftUI
import Testing
import UIKit

/// The colour the user's own rating is drawn in, the site's red, green or blue (the designer). The plain system
/// `.green` is about 2.2:1 on the white row, so each colour has a darker light-mode value and the system's dark-mode
/// one.
struct UserRatingTintColorTests {
    @Test(arguments: [
        (UserRatingTint.red, 0xD7_00_15, 0xFF_45_3A),
        (.green, 0x24_8A_3D, 0x30_D1_58),
        (.blue, 0x00_40_DD, 0x0A_84_FF)
    ])
    func eachTintHasItsColourInEachAppearance(_ tint: UserRatingTint, _ light: Int, _ dark: Int) {
        #expect(Self.hex(of: tint.color, in: .light) == light)
        #expect(Self.hex(of: tint.color, in: .dark) == dark)
    }

    /// The stars are a graphical object: at least 3:1 against the white light row and the black dark one.
    @Test(arguments: [UserRatingTint.red, .green, .blue])
    func everyTintStandsOutFromItsRow(_ tint: UserRatingTint) {
        #expect(Self.contrast(Self.hex(of: tint.color, in: .light), 0xFF_FF_FF) >= 3)
        #expect(Self.contrast(Self.hex(of: tint.color, in: .dark), 0x00_00_00) >= 3)
    }

    private static func hex(of color: Color, in style: UIUserInterfaceStyle) -> Int {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        let byte = { (component: CGFloat) in Int((component * 255).rounded()) }
        return byte(red) << 16 | byte(green) << 8 | byte(blue)
    }

    private static func contrast(_ lhs: Int, _ rhs: Int) -> Double {
        func linear(_ channel: Int) -> Double {
            let value = Double(channel & 0xFF) / 255
            return value <= 0.040_45 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        func luminance(_ hex: Int) -> Double {
            0.2126 * linear(hex >> 16) + 0.7152 * linear(hex >> 8) + 0.0722 * linear(hex)
        }
        let lighter = max(luminance(lhs), luminance(rhs))
        let darker = min(luminance(lhs), luminance(rhs))
        return (lighter + 0.05) / (darker + 0.05)
    }
}
