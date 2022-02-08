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
