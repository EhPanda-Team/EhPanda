//
//  TagTranslator.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/04.
//

import OpenCC
import Foundation

struct TagTranslator: Codable, Equatable {
    var language: TranslatableLanguage?
    var hasCustomTranslations = false
    var updatedDate: Date = .distantPast
    var translations = [TagTranslation]()

    func lookup(word: String, returnOriginal: Bool) -> (String, TagTranslation?) {
        guard !returnOriginal else { return (word, nil) }
        let (lhs, rhs) = word.stringsBesideColon

        guard let translation = translations.first(where: {
            $0.key.caseInsensitiveEqualsTo(rhs)
        }) else { return (word, nil) }

        var result = translation.displayValue
        if let lhs = lhs {
            result = [lhs, ":", result].joined()
        }
        return (result, translation)
    }
}

extension TagTranslator: CustomStringConvertible {
    var description: String {
        let params = String(describing: [
            "language": language as Any,
            "updatedDate": updatedDate,
            "translationsCount": translations.count,
            "hasCustomTranslations": hasCustomTranslations
        ])
        return "TagTranslator(\(params))"
    }
}

struct TagTranslation: Codable, Equatable, Hashable {
    let namespace: TagNamespace
    let key: String
    let value: String
    var description: String?

    var displayValue: String {
        valuePlainText ?? value
    }

    var valuePlainText: String? {
        MarkdownUtil.ripImage(string: value)
    }
    var valueImageURL: URL? {
        if let imageURLString = MarkdownUtil.parseImage(string: value) {
            return .init(string: imageURLString)
        }
        return nil
    }

    var searchKeyword: String {
        [namespace.abbreviation ?? namespace.rawValue, ":",
         key.contains(" ") ? "\"\(key)$\"" : "\(key)$"].joined()
    }

    func getSuggestion(keyword: String) -> TagSuggestion {
        func getWeight(value: String, range: Range<String.Index>) -> Float {
            namespace.weight * .init(keyword.count + 1) / .init(value.count)
            * (range.contains(value.startIndex) ? 2.0 : 1.0)
        }

        var weight: Float = .zero
        let keyRange = key.range(of: keyword, options: .caseInsensitive)
        let valueRange = value.range(of: keyword, options: .caseInsensitive)
        if let range = keyRange { weight += getWeight(value: key, range: range) }
        if let range = valueRange { weight += getWeight(value: value, range: range) }
        return .init(tag: self, weight: weight, keyRange: keyRange, valueRange: valueRange)
    }
}

extension Array where Element == TagTranslation {
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
        return map {
            .init(
                namespace: $0.namespace, key: $0.key,
                value: customConversion(text: converter.convert($0.value)),
                description: $0.description
            )
        }
    }
}
