//
//  TagTranslation.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/26.
//

import OpenCC
import Foundation

struct TagTranslation: Codable, Equatable, Hashable {
    let namespace: TagNamespace
    let key: String
    let value: String
    var description: String?
    var linksString: String?

    var displayValue: String {
        valuePlainText ?? value
    }

    var valuePlainText: String? {
        MarkdownUtil.parseTexts(markdown: value).first
    }
    var valueImageURL: URL? {
        MarkdownUtil.parseImages(markdown: value).first
    }
    var descriptionPlainText: String? {
        if let description = description {
            return MarkdownUtil.parseTexts(markdown: description.replacingOccurrences(of: "`", with: " ")).joined()
        }
        return nil
    }
    var descriptionImageURLs: [URL] {
        if let description = description {
            return MarkdownUtil.parseImages(markdown: description)
        }
        return .init()
    }
    var links: [URL] {
        if let linksString = linksString {
            return MarkdownUtil.parseLinks(markdown: linksString)
        }
        return .init()
    }

    var searchKeyword: String {
        [namespace.abbreviation ?? namespace.rawValue, ":",
         key.contains(" ") ? "\"\(key)$\"" : "\(key)$"].joined()
    }

    func getSuggestion(keyword: String, originalKeyword: String, matchesNamespace: Bool) -> TagSuggestion {
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

extension Dictionary where Value == TagTranslation {
    var chtConverted: Self {
        func customConversion(text: String) -> String {
            switch text {
            case "full color":
                return "全彩"
            default:
                return text
            }
        }

        guard let preferredLanguage = Locale.preferredLanguages.first else { return self }

        var options: ChineseConverter.Options = [.traditionalize]
        if preferredLanguage.contains("HK") {
            options = [.traditionalize, .hkStandard]
        } else if preferredLanguage.contains("TW") {
            options = [.traditionalize, .twStandard, .twIdiom]
        }

        guard let converter = try? ChineseConverter(options: options) else { return self }
        var dictionary = self
        dictionary.forEach { (key, value) in
            dictionary[key] = TagTranslation(
                namespace: value.namespace, key: value.key,
                value: customConversion(text: converter.convert(value.value)),
                description: value.description, linksString: value.linksString
            )
        }
        return dictionary
    }
}
