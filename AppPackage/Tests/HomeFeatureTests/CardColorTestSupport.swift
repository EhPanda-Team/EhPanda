import Foundation
import SwiftUI
import UIKit

extension Color.Resolved {
    /// Bright colors real cover palettes produced (the white fallback among them), and the sRGB primaries.
    static let brightCoverColors: [Self] = [
        0xFFFFFF, 0x00E4FF, 0xFCA89E, 0xDED2BC, 0xBFC1E1, 0xFF6597, 0xEE425F, 0x03B2FC,
        0xFF0000, 0x00FF00, 0x0000FF, 0xFFFF00, 0x00FFFF, 0xFF00FF
    ].map(Self.init(hex:))

    /// Dark colors real cover palettes produced, all below the knee of both dark-mode ceilings.
    static let darkCoverColors: [Self] = [0x000000, 0x060606, 0x180B19, 0x312C29].map(Self.init(hex:))

    static let grays: [Self] = stride(from: 0, through: 255, by: 5).map({ Self(hex: 0x010101 * $0) })

    /// The outer surface of the sRGB cube in steps of 1/8: every hue at full and partial saturation.
    static let gamutSurface: [Self] = {
        let steps = (0...8).map({ Float($0) / 8 })
        return steps.flatMap { red in
            steps.flatMap { green in
                steps.compactMap { blue in
                    max(red, green, blue) == 1 ? Self(red: red, green: green, blue: blue) : nil
                }
            }
        }
    }()

    init(hex: Int) {
        self.init(
            red: Float((hex >> 16) & 0xFF) / 255,
            green: Float((hex >> 8) & 0xFF) / 255,
            blue: Float(hex & 0xFF) / 255
        )
    }

    init(_ color: UIColor) {
        self = Color(uiColor: color).resolve(in: EnvironmentValues())
    }

    /// WCAG relative luminance.
    var relativeLuminance: Double {
        Double(0.2126 * linearRed + 0.7152 * linearGreen + 0.0722 * linearBlue)
    }

    /// WCAG contrast of this color, composited over `background` the way a translucent label is drawn.
    func contrastRatio(over background: Self) -> Double {
        let text = Self(
            red: red * opacity + background.red * (1 - opacity),
            green: green * opacity + background.green * (1 - opacity),
            blue: blue * opacity + background.blue * (1 - opacity)
        )
        let lighter = max(text.relativeLuminance, background.relativeLuminance)
        let darker = min(text.relativeLuminance, background.relativeLuminance)
        return (lighter + 0.05) / (darker + 0.05)
    }
}

/// The card's text: SwiftUI's `.primary` and `.secondary` render as UIKit's label and secondaryLabel,
/// which Increase Contrast makes more opaque.
struct CardText {
    let primary: Color.Resolved
    let secondary: Color.Resolved

    @MainActor
    init(_ scheme: ColorScheme, _ contrast: ColorSchemeContrast) {
        let traits = UITraitCollection { traits in
            traits.userInterfaceStyle = scheme == .dark ? .dark : .light
            traits.accessibilityContrast = contrast == .increased ? .high : .normal
        }
        primary = Color.Resolved(UIColor.label.resolvedColor(with: traits))
        secondary = Color.Resolved(UIColor.secondaryLabel.resolvedColor(with: traits))
    }
}
