public import CoreGraphics
public import Foundation
public import SwiftUI
public import UIKit

/// Keeps a title's last line from holding a single word (UI-SPEC C-3, lead msg 1900).
///
/// Shared by the first-launch titles (18-09) and the Blocked Users empty state (18-10). SwiftUI pulls a word down to
/// keep a single word off the last line in English but not reliably in German, so a title joins its last two words
/// with a no-break space when the pair fits on one line at the current width and text size. The catalog string and
/// the visible words are unchanged, and VoiceOver reads the string as written.
public enum TitleWidowGuard {
    public static let noBreakSpace: Character = "\u{00A0}"

    /// `title` with its last two words joined by a no-break space when `fits` says the joined pair fits on one line;
    /// otherwise `title` unchanged, so a pair wider than the line is never broken mid-word. Titles of one word, and
    /// titles in Japanese and Chinese, whose lines break between characters, are returned unchanged.
    public static func guarded(_ title: String, languageCode: String?, fits: (String) -> Bool) -> String {
        guard !["ja", "zh"].contains(languageCode),
              let lastSpace = title.lastIndex(of: " ")
        else { return title }
        let pairStart = title[..<lastSpace].lastIndex(of: " ").map(title.index(after:)) ?? title.startIndex
        var pair = String(title[pairStart...])
        guard let pairSpace = pair.lastIndex(of: " ") else { return title }
        pair.replaceSubrange(pairSpace...pairSpace, with: String(noBreakSpace))
        guard fits(pair) else { return title }
        return String(title[..<pairStart]) + pair
    }

    /// `title` guarded for a line `width` points wide, measured in `font`, in the language the app's strings resolved
    /// to. A width of zero, before the title has been laid out, returns `title` unchanged.
    public static func guarded(_ title: String, width: CGFloat, font: UIFont) -> String {
        guard width > 0 else { return title }
        return guarded(title, languageCode: ResolvedAppLanguage.code) { unit in
            ceil((unit as NSString).size(withAttributes: [.font: font]).width) <= width
        }
    }

    /// The UIKit twin of `Font.<style>.bold()` at `size`, for measuring a title in the font it is drawn in.
    public static func boldFont(_ style: UIFont.TextStyle, at size: DynamicTypeSize) -> UIFont {
        let traits = UITraitCollection(preferredContentSizeCategory: UIContentSizeCategory(size))
        let font = UIFont.preferredFont(forTextStyle: style, compatibleWith: traits)
        guard let bold = font.fontDescriptor.withSymbolicTraits(.traitBold) else { return font }
        return UIFont(descriptor: bold, size: 0)
    }
}

/// The language the app's strings resolved to, such as `en` or `zh` (for zh-Hans and zh-Hant).
public enum ResolvedAppLanguage {
    public static var code: String? {
        Bundle.main.preferredLocalizations.first
            .flatMap({ Locale(identifier: $0).language.languageCode?.identifier })
    }
}
