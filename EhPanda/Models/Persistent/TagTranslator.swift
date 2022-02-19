//
//  TagTranslator.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/04.
//

import Foundation

struct TagTranslator: Codable, Equatable {
    var language: TranslatableLanguage?
    var hasCustomTranslations: Bool = false
    var updatedDate: Date = .distantPast
    var contents = [String: String]()

    private func lookup(text: String) -> String {
        guard let translatedText = contents[text],
              !translatedText.isEmpty
        else { return text }

        return translatedText
    }
    func tryTranslate(text: String, returnOriginal: Bool) -> String {
        guard !returnOriginal else { return text }
        if let range = text.range(of: ":") {
            let before = text[...range.lowerBound]
            let after = String(text[range.upperBound...])
            let result = before + lookup(text: after)
            return String(result)
        }
        return lookup(text: text)
    }
}

extension TagTranslator: CustomStringConvertible {
    var description: String {
        let params = String(describing: [
            "language": language as Any,
            "updatedDate": updatedDate,
            "contentsCount": contents.count,
            "hasCustomTranslations": hasCustomTranslations
        ])
        return "TagTranslator(\(params))"
    }
}

struct TagTranslation: Identifiable {
    let id: UUID = .init()
    let namespace: TagNamespace
    let key: String
    let value: String
    var description: String?

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
        return TagSuggestion(tag: self, weight: weight, keyRange: keyRange, valueRange: valueRange)
    }
}
