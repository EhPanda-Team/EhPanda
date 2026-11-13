public import SwiftUI

extension Defaults {
    /// The colours of the ten favorites slots, in slot order (slot 0 first): the tints the site draws on its
    /// favorite icons.
    public struct FavoriteColor: Sendable {
        public static let colors: [Color] = [
            Color(hex: "9e9e9e"),
            Color(hex: "fc4e4e"),
            Color(hex: "fcb417"),
            Color(hex: "dde500"),
            Color(hex: "17b91b"),
            Color(hex: "36b940"),
            Color(hex: "68c9de"),
            Color(hex: "5050d7"),
            Color(hex: "9755f5"),
            Color(hex: "fe93ff")
        ]

        /// The colour of favorites slot `index`, or `nil` for no slot or one outside the ten (a parsed number is
        /// only as good as the page it came from, so it is never used to index the palette unchecked).
        public static func color(at index: Int?) -> Color? {
            guard let index, index >= 0 else { return nil }
            return colors.dropFirst(index).first
        }
    }
}
