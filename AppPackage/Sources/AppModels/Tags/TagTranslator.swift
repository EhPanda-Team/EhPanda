import Foundation

public struct TagTranslator: Codable, Equatable, Sendable {
    public init(
        language: TranslatableLanguage? = nil,
        hasCustomTranslations: Bool = false,
        updatedDate: Date = .distantPast,
        translations: [String: TagTranslation] = [String: TagTranslation]()
    ) {
        self.language = language
        self.hasCustomTranslations = hasCustomTranslations
        self.updatedDate = updatedDate
        self.translations = translations
    }
    public var language: TranslatableLanguage?
    public var hasCustomTranslations = false
    public var updatedDate: Date = .distantPast
    public var translations = [String: TagTranslation]()

    public func lookup(word: String, returnOriginal: Bool) -> (String, TagTranslation?) {
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
}

extension TagTranslator: CustomStringConvertible {
    public var description: String {
        let params = String(describing: [
            "language": language as Any,
            "updatedDate": updatedDate,
            "translationsCount": translations.count,
            "hasCustomTranslations": hasCustomTranslations
        ])
        return "TagTranslator(\(params))"
    }
}
