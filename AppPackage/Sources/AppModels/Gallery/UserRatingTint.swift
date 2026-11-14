public import SwiftUI
import UIKit

/// The colour the site draws the signed-in user's own rating in, named by the star class it puts on the rating
/// (`irr`, `irg`, `irb`). A gallery the user has not rated has none and its stars are the plain average.
public enum UserRatingTint: String, Codable, Equatable, Sendable {
    case red
    case green
    case blue
}

extension UserRatingTint {
    /// The colour the stars of this rating are drawn in, in the list and on the detail page alike (the designer).
    /// The system's plain colours are too light on the white light-mode row (`.green` is about 2.2:1), so light mode
    /// takes darker values; dark mode takes the system's dark ones.
    public var color: Color {
        Color(uiColor: UIColor { traits in
            traits.userInterfaceStyle == .dark ? darkColor : lightColor
        })
    }

    private var lightColor: UIColor {
        switch self {
        case .red: UIColor(hex: 0xD7_00_15)
        case .green: UIColor(hex: 0x24_8A_3D)
        case .blue: UIColor(hex: 0x00_40_DD)
        }
    }

    private var darkColor: UIColor {
        switch self {
        case .red: UIColor(hex: 0xFF_45_3A)
        case .green: UIColor(hex: 0x30_D1_58)
        case .blue: UIColor(hex: 0x0A_84_FF)
        }
    }
}

private extension UIColor {
    convenience init(hex: Int) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: 1
        )
    }
}
