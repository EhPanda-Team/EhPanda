//
//  TagTranslator.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/02/04.
//

import Foundation

struct TagTranslator: Codable, Equatable {
    var language: TranslatableLanguage?
    var hasCustomTranslations = false
    var updatedDate: Date = .distantPast
    var translations = [String: TagTranslation]()

    func lookup(word: String, returnOriginal: Bool) -> (String, TagTranslation?) {
        guard !returnOriginal else { return (word, nil) }
        let (lhs, rhs) = word.stringsBesideColon

        var key = rhs
        if let lhs = lhs {
            key = lhs + rhs
        }
        guard let translation = translations[key] else { return (word, nil) }

        var result = translation.displayValue
        if let lhs = lhs {
            result = [lhs, ":", result].joined()
        }
        return (result, translation)
    }

    func lookupMultiple(text: String) -> [(String, TagTranslation?)] {
        let keyword = text.lowercased().replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        guard let regex = Defaults.Regex.tagSuggestion else { return [] }
        let values: [String] = regex.matches(in: keyword, range: .init(location: 0, length: keyword.count))
            .compactMap {
                if let range = Range($0.range, in: keyword) {
                    // f:"chinese dress$" -> :"  -> f:chinese dress$"
                    //                    -> "$  -> f:chinese dress$
                    //                    -> \$$ -> f:chinese dress
                    return .init(keyword[range])
                        .replacingOccurrences(of: ":\"", with: ":", options: .regularExpression)
                        .replacingOccurrences(of: "\"$", with: "", options: .regularExpression)
                        .replacingOccurrences(of: "\\$$", with: "", options: .regularExpression)
                } else {
                    return nil
                }
            }
        return values.map {
            let (lhs, rhs) = $0.stringsBesideColon
            var key = rhs
            var result: [String] = []
            if var lhs = lhs {
                if let namespace = TagNamespace.allCases
                    .first(where: { $0.rawValue == lhs || $0.abbreviation == lhs}) {
                    lhs = namespace.rawValue
//                    result.append(namespace.value)
//                    result.append(":")
                }
                key = lhs + rhs
            }
            if let translation = translations[key] {
                result.append(translation.displayValue)
                return (result.joined(), translation)
            } else {
                result.append(rhs)
                return (result.joined(), nil)
            }
        }
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
