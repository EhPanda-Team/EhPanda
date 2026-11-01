import AppModels
import Foundation

extension Gallery {
    var homeSlideshowTags: [GalleryTag.Content] {
        var names: Set<String> = [normalizedTagName(category.rawValue)]
        let creators: Set<String> = ["artist", "group"]
        let titleNames = bracketedContents(in: title).map(normalizedTagName)
        return Array(tags
            .filter({ $0.namespace != .language })
            .flatMap(\.contents)
            .filter({ $0.voteStrength == .strong })
            .sorted { lhs, rhs in
                return creators.contains(lhs.rawNamespace) && !creators.contains(rhs.rawNamespace)
            }
            .filter { tag in
                let name = normalizedTagName(tag.text)
                return !name.isEmpty && !titleNames.contains(where: { $0.contains(name) })
                    && names.insert(name).inserted
            }
            .prefix(3))
    }
}

/// Padding enforces whole-word/phrase matches: “art” must not match “cartoon”.
private func normalizedTagName(_ text: String) -> String {
    let folded = text.folding(
        options: [.caseInsensitive, .widthInsensitive], locale: Locale(identifier: "en_US_POSIX")
    )
    let words = String(folded.unicodeScalars.map { scalar in
        CharacterSet.alphanumerics.contains(scalar) ? Character(String(scalar)) : " "
    }).split(whereSeparator: \.isWhitespace)
    return words.isEmpty ? "" : " " + words.joined(separator: " ") + " "
}

/// Only balanced brackets contribute exclusions. Nested names remain available in their outer group.
private func bracketedContents(in title: String) -> [String] {
    let pairs: [Character: Character] = [
        "(": ")", "[": "]", "{": "}", "<": ">", "（": "）", "［": "］", "｛": "｝",
        "〈": "〉", "《": "》", "「": "」", "『": "』", "【": "】", "〔": "〕",
        "〖": "〗", "〘": "〙", "〚": "〛"
    ]
    var openings: [(start: String.Index, closing: Character)] = []
    var contents: [String] = []
    for (index, character) in zip(title.indices, title) {
        if let closing = pairs[character] {
            openings.append((start: title.index(after: index), closing: closing))
        } else if let opening = openings.last, opening.closing == character {
            contents.append(String(title[opening.start..<index]))
            openings.removeLast()
        }
    }
    return contents
}
