import Foundation

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
