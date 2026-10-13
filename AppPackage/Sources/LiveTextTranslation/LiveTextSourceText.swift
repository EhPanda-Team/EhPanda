import AppModels
import Foundation

/// A recognized group's text as Live Text sends it to translation.
///
/// Vision reads a group line by line, and the lines are joined back the way the language writes them:
/// CJK text runs on without a space, a word hyphenated across two lines is joined again, and any other
/// line break becomes one space. A group without a single letter, such as a page number, "!!" or "...",
/// has nothing to translate.
public struct LiveTextSourceText: Equatable, Sendable {
    public let groupID: UUID
    public let text: String

    public init(groupID: UUID, text: String) {
        self.groupID = groupID
        self.text = text
    }

    /// The text of `group`, or `nil` when it holds no letter.
    public init?(group: LiveTextGroup) {
        let text = Self.joined(lines: group.blocks.map(\.text))
        guard text.unicodeScalars.contains(where: \.properties.isAlphabetic) else {
            return nil
        }
        self.init(groupID: group.id, text: text)
    }

    /// This text as the translation of `pair` reads it best.
    ///
    /// Comic lettering is often all capitals, and a translation into a script with letter case keeps
    /// them: an all-caps English line comes back as all-caps German. Such lettering is sentence-cased
    /// first. A translation into a script without case reads the capitals well, so it gets the
    /// lettering unchanged, which keeps a name recognizable as a name.
    public func prepared(for pair: LiveTextLanguagePair) -> Self {
        guard pair.target.writesInCase, Self.isAllCaps(text) else {
            return self
        }
        return Self(groupID: groupID, text: Self.sentenceCased(text, in: pair.source))
    }
}

// MARK: Joining
extension LiveTextSourceText {
    static func joined(lines: [String]) -> String {
        var result = ""
        for line in lines.map(collapsingWhitespace) where !line.isEmpty {
            guard let last = result.last, let first = line.first else {
                result = line
                continue
            }
            if let hyphenated = result.dropLast().last, last.isHyphen, hyphenated.isLetter, first.isLetter {
                // A word split across two lines: letters of one case on both sides are one word broken
                // at a syllable ("BE-" "LIEVE"); a change of case is a hyphenated name ("Spider-" "Man").
                if hyphenated.isUppercase == first.isUppercase {
                    result.removeLast()
                }
                result += line
            } else if last.isCJK, first.isCJK {
                result += line
            } else {
                result += " " + line
            }
        }
        return result
    }

    private static func collapsingWhitespace(_ line: String) -> String {
        line.split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }
}

// MARK: Letter case
extension LiveTextSourceText {
    /// Whether `text` is lettered in capitals: at least four cased letters, at least 80% of them
    /// uppercase, so a stray lowercase misreading does not keep a line from counting.
    static func isAllCaps(_ text: String) -> Bool {
        let cased = text.filter({ $0.isUppercase || $0.isLowercase })
        guard cased.count >= 4 else {
            return false
        }
        let uppercase = cased.filter(\.isUppercase).count
        return Double(uppercase) >= Double(cased.count) * 0.8
    }

    /// `text` in lowercase, with the first letter of each sentence capitalized and, in English, the
    /// pronoun "I".
    static func sentenceCased(_ text: String, in language: Locale.Language) -> String {
        let lowercased = text.lowercased(with: Locale(identifier: language.minimalIdentifier))
        var result = ""
        var capitalizesNext = true
        for character in lowercased {
            if capitalizesNext, character.isLetter {
                result += character.uppercased()
                capitalizesNext = false
            } else {
                result.append(character)
            }
            if character.endsSentence {
                capitalizesNext = true
            }
        }
        guard language.languageCode == .english else {
            return result
        }
        // Simple word boundaries, so "i'm" and "i'll" are found too: Unicode's default rules read a
        // contraction as one word.
        return result.replacing(/\bi\b/.wordBoundaryKind(.simple), with: "I")
    }
}

private extension Character {
    /// Whether the character belongs to a script written without spaces between words: Han, kana and
    /// the CJK punctuation and full-width forms set with them. Hangul is written with spaces.
    var isCJK: Bool {
        guard let scalar = unicodeScalars.first else {
            return false
        }
        if scalar.properties.isIdeographic {
            return true
        }
        return switch scalar.value {
        case 0x3000...0x30FF, 0x31F0...0x31FF, 0xFF00...0xFFEF:
            true
        default:
            false
        }
    }

    var endsSentence: Bool {
        ".!?\u{2026}\u{3002}\u{FF01}\u{FF1F}".contains(self)
    }

    var isHyphen: Bool {
        self == "-" || self == "\u{2010}"
    }
}
