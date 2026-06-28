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
