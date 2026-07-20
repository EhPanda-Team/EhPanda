import Foundation

/// The outcome of translating one tag word.
///
/// A named type rather than a `(String, TagTranslation?)` pair because the pair was declared
/// thirteen times across four modules and read positionally as `.1`, which is the shape that
/// silently mis-indexes the moment an element is added or reordered.
public struct TagTranslationLookup: Equatable, Hashable, Sendable {
    public init(text: String, translation: TagTranslation?) {
        self.text = text
        self.translation = translation
    }

    /// The text to display: the translated value when one was found, otherwise the original word.
    public let text: String
    /// The matched translation, absent when the word has none or translation is switched off.
    public let translation: TagTranslation?
}

public struct TagTranslation: Codable, Equatable, Hashable, Sendable {
    public init(
        namespace: TagNamespace,
        key: String,
        value: String,
        description: String? = nil,
        linksString: String? = nil
    ) {
        self.namespace = namespace
        self.key = key
        self.value = value
        self.description = description
        self.linksString = linksString
    }
    public let namespace: TagNamespace
    public let key: String
    public let value: String
    public var description: String?
    public var linksString: String?

    public var searchKeyword: String {
        [namespace.abbreviation ?? namespace.rawValue, ":",
         key.contains(" ") ? "\"\(key)$\"" : "\(key)$"].joined()
    }

    public func getSuggestion(keyword: String, originalKeyword: String, matchesNamespace: Bool) -> TagSuggestion {
        func getWeight(value: String, range: Range<String.Index>) -> Float {
            namespace.weight * .init(keyword.count + 1) / .init(value.count)
                * (range.lowerBound == value.startIndex ? 2.0 : 1.0)
        }

        var weight: Float = .zero
        let keyRange = key.range(of: keyword, options: .caseInsensitive)
        let valueRange = value.range(of: keyword, options: .caseInsensitive)
        if let range = keyRange { weight += getWeight(value: key, range: range) }
        if let range = valueRange { weight += getWeight(value: value, range: range) }
        return .init(
            tag: self, weight: weight, keyRange: keyRange, valueRange: valueRange,
            originalKeyword: originalKeyword, matchesNamespace: matchesNamespace
        )
    }
}
