import CommonMarkExt
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

    public var displayValue: String {
        valuePlainText ?? value
    }

    public var valuePlainText: String? {
        MarkdownUtil.parseTexts(markdown: value).first
    }
    public var valueImageURL: URL? {
        MarkdownUtil.parseImages(markdown: value).first
    }
    public var descriptionPlainText: String? {
        if let description = description {
            return MarkdownUtil.parseTexts(markdown: description.replacingOccurrences(of: "`", with: " ")).joined()
        }
        return nil
    }
    public var descriptionImageURLs: [URL] {
        if let description = description {
            return MarkdownUtil.parseImages(markdown: description)
        }
        return .init()
    }
    public var links: [URL] {
        if let linksString = linksString {
            return MarkdownUtil.parseLinks(markdown: linksString)
        }
        return .init()
    }

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
