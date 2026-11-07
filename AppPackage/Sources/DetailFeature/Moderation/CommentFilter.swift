import Foundation

/// The posting filter: whether a comment's text contains a term from the moderation list (DD-04, D-12).
///
/// Pure and local: the text never leaves the device for filtering, and a match only raises the posting warning,
/// which the user can dismiss with Post Anyway. A match never names the term (D-12), so this answers yes or no.
///
/// The list and the text are normalised the same way (``normalized(_:)``), then each term is matched by its script
/// (research §5.3):
/// - A term with any Han, kana or Hangul character matches as a substring, because those scripts put no spaces
///   between words and Korean particles attach to the noun.
/// - Any other term matches only as whole words, so a term inside a longer innocent word does not match. A plural
///   or an inflected form is therefore its own entry in the list.
///
/// A term may list exception words, the ordinary words that hold it (``CommentFilterTerms``): an occurrence inside one
/// of them does not match, so a short CJK term stays in the list without flagging the everyday word around it.
///
/// `.diacriticInsensitive` also strips Japanese dakuten (が → か, Pitfall P-6). Folding both sides the same way keeps
/// every listed term matching, and the few extra matches it causes only show a warning that can be dismissed.
enum CommentFilter {
    /// Whether `text` contains any term of `terms`.
    static func matches(_ text: String, terms: CommentFilterTerms) -> Bool {
        let text = normalized(text)
        guard !text.isEmpty else { return false }
        return terms.matchers.contains(where: { $0.matches(in: text) })
    }

    /// Folds case, width and diacritics, unifies apostrophes and collapses every run of whitespace to one space.
    ///
    /// Idempotent: normalising a normalised string changes nothing, so the bundled list can be stored normalised and
    /// checked for it. Hangul is recomposed after folding, so a syllable never matches part of another.
    static func normalized(_ text: String) -> String {
        let folded = text
            .folding(options: [.caseInsensitive, .widthInsensitive, .diacriticInsensitive], locale: nil)
            .precomposedStringWithCanonicalMapping
        var result = ""
        var pendingSpace = false
        for character in folded {
            if character.isWhitespace {
                pendingSpace = !result.isEmpty
                continue
            }
            if pendingSpace {
                result.append(" ")
                pendingSpace = false
            }
            result.append(apostrophes.contains(character) ? "'" : character)
        }
        return result
    }

    /// Typographic apostrophes a phone keyboard types for `'`.
    private static let apostrophes: Set<Character> = ["\u{2019}", "\u{2018}", "\u{02BC}", "\u{FF07}"]
}

/// One normalised term with the matching rule its script calls for, and the ordinary words it does not count inside.
struct CommentFilterMatcher: Equatable, Sendable {
    let term: String
    let isSubstring: Bool
    /// Normalised words that hold the term, inside which an occurrence of it does not match.
    let exceptions: [String]

    /// `nil` for a term that normalises to nothing, which would otherwise match every text.
    ///
    /// - Parameter exceptions: Exception words by normalised term; only the words that hold this term are kept.
    init?(term: String, exceptions: [String: [String]] = [:]) {
        let term = CommentFilter.normalized(term)
        guard !term.isEmpty else { return nil }
        self.term = term
        isSubstring = term.unicodeScalars.contains(where: CommentFilterScript.isUnspaced)
        self.exceptions = (exceptions[term] ?? []).filter({ $0 != term && $0.contains(term) })
    }

    func matches(in text: String) -> Bool {
        let excused = exceptions.flatMap({ Self.ranges(of: $0, in: text) })
        return Self.ranges(of: term, in: text).contains { range in
            guard isSubstring || isWholeWord(range, in: text) else { return false }
            return !excused.contains(where: { $0.lowerBound <= range.lowerBound && range.upperBound <= $0.upperBound })
        }
    }

    private func isWholeWord(_ range: Range<String.Index>, in text: String) -> Bool {
        let startsWord = range.lowerBound == text.startIndex
            || !CommentFilterScript.isWordCharacter(text[text.index(before: range.lowerBound)])
        let endsWord = range.upperBound == text.endIndex
            || !CommentFilterScript.isWordCharacter(text[range.upperBound])
        return startsWord && endsWord
    }

    /// Every occurrence of `word` in `text`, overlapping ones included.
    private static func ranges(of word: String, in text: String) -> [Range<String.Index>] {
        var ranges = [Range<String.Index>]()
        var searchRange = text.startIndex..<text.endIndex
        while let range = text.range(of: word, range: searchRange) {
            ranges.append(range)
            searchRange = text.index(after: range.lowerBound)..<text.endIndex
        }
        return ranges
    }
}

/// Script classification for the matching rules.
enum CommentFilterScript {
    /// A letter or digit of a script that separates words with spaces; Han, kana and Hangul are word boundaries
    /// for a Latin term, so "slur" still matches in "这是slur吧".
    static func isWordCharacter(_ character: Character) -> Bool {
        guard character.isLetter || character.isNumber else { return false }
        return !character.unicodeScalars.contains(where: isUnspaced)
    }

    /// Han, Hiragana, Katakana (including the half-width and phonetic-extension blocks) and Hangul.
    static func isUnspaced(_ scalar: Unicode.Scalar) -> Bool {
        unspacedRanges.contains(where: { $0.contains(scalar.value) })
    }

    private static let unspacedRanges: [ClosedRange<UInt32>] = [
        0x1100...0x11FF, // Hangul Jamo
        0x3040...0x309F, // Hiragana
        0x30A0...0x30FF, // Katakana
        0x3130...0x318F, // Hangul Compatibility Jamo
        0x31F0...0x31FF, // Katakana Phonetic Extensions
        0x3400...0x4DBF, // CJK Unified Ideographs Extension A
        0x4E00...0x9FFF, // CJK Unified Ideographs
        0xA960...0xA97F, // Hangul Jamo Extended-A
        0xAC00...0xD7AF, // Hangul Syllables
        0xD7B0...0xD7FF, // Hangul Jamo Extended-B
        0xF900...0xFAFF, // CJK Compatibility Ideographs
        0xFF65...0xFFDC, // Half-width Katakana and Hangul
        0x20000...0x3134F // CJK Unified Ideographs Extensions B to G
    ]
}
