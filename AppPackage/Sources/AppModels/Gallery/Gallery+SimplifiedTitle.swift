import Foundation

extension Gallery {
    /// A list-only presentation. The stored title and search/detail text remain unchanged.
    public var simplifiedTitle: String {
        var expectedClosings: [Character] = []
        var openingIndex: String.Index?
        var ranges: [Range<String.Index>] = []
        for (index, rawCharacter) in zip(title.indices, title) {
            // Fold only the delimiter lookup, never the retained title (e.g. halfwidth kana).
            let delimiter = String(rawCharacter).precomposedStringWithCompatibilityMapping
            guard delimiter.count == 1, let character = delimiter.first else { continue }
            if let closing = titleBracketPairs[character] {
                if expectedClosings.isEmpty { openingIndex = index }
                expectedClosings.append(closing)
            } else if character == expectedClosings.last {
                expectedClosings.removeLast()
                if expectedClosings.isEmpty, let start = openingIndex {
                    ranges.append(start..<title.index(after: index))
                    openingIndex = nil
                }
            } else if titleClosingBrackets.contains(character), !expectedClosings.isEmpty {
                // A mismatched group is literal text; do not discard part of an unfinished title.
                expectedClosings.removeAll(keepingCapacity: true)
                openingIndex = nil
            }
        }

        var result = ""
        var cursor = title.startIndex
        for range in ranges {
            result += title[cursor..<range.lowerBound]
            var removedWhitespace = false
            while result.last?.isWhitespace == true {
                result.removeLast()
                removedWhitespace = true
            }
            cursor = range.upperBound
            while cursor < title.endIndex, title[cursor].isWhitespace {
                cursor = title.index(after: cursor)
                removedWhitespace = true
            }
            if removedWhitespace, !result.isEmpty, cursor < title.endIndex {
                result.append(" ")
            }
        }
        result += title[cursor...]
        result = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? title.trimmingCharacters(in: .whitespacesAndNewlines) : result
    }
}

// Unicode 17 BidiBrackets pairs, plus enclosing quotation marks and ASCII/fullwidth angle brackets.
// Compatibility folding also recognizes vertical, small, fullwidth and halfwidth presentation forms.
// Source: https://www.unicode.org/Public/17.0.0/ucd/BidiBrackets.txt
private let titleBracketPairs: [Character: Character] = {
    let pairs = [
        "()", "[]", "{}", "༺༻", "༼༽", "᚛᚜", "⁅⁆", "⁽⁾", "₍₎", "⌈⌉", "⌊⌋", "〈〉",
        "❨❩", "❪❫", "❬❭", "❮❯", "❰❱", "❲❳", "❴❵", "⟅⟆", "⟦⟧", "⟨⟩", "⟪⟫", "⟬⟭", "⟮⟯",
        "⦃⦄", "⦅⦆", "⦇⦈", "⦉⦊", "⦋⦌", "⦍⦐", "⦏⦎", "⦑⦒", "⦓⦔", "⦕⦖", "⦗⦘", "⧘⧙", "⧚⧛", "⧼⧽",
        "⸢⸣", "⸤⸥", "⸦⸧", "⸨⸩", "⹕⹖", "⹗⹘", "⹙⹚", "⹛⹜", "〈〉", "《》", "「」", "『』", "【】",
        "〔〕", "〖〗", "〘〙", "〚〛", "﹙﹚", "﹛﹜", "﹝﹞", "（）", "［］", "｛｝", "｟｠", "｢｣",
        "<>", "«»", "‹›", "“”", "‘’", "﴿﴾"
    ]
    return pairs.reduce(into: [:]) { result, pair in
        let normalized = pair.precomposedStringWithCompatibilityMapping
        if let opening = normalized.first, let closing = normalized.last {
            result[opening] = closing
        }
    }
}()
private let titleClosingBrackets = Set(titleBracketPairs.values)
