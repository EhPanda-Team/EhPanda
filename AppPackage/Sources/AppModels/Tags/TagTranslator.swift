public struct TagTranslator: Codable, Equatable, Sendable {
    public init(
        language: TranslatableLanguage? = nil,
        hasCustomTranslations: Bool = false,
        digest: String? = nil,
        translations: [String: TagTranslation] = [String: TagTranslation]()
    ) {
        self.language = language
        self.hasCustomTranslations = hasCustomTranslations
        self.digest = digest
        self.translations = translations
    }
    public var language: TranslatableLanguage?
    public var hasCustomTranslations = false
    /// The release asset digest of the loaded table; `nil` when nothing downloaded is loaded.
    public var digest: String?
    public var translations = [String: TagTranslation]()
}

extension TagTranslator: CustomStringConvertible {
    public var description: String {
        let params = String(describing: [
            "language": language as Any,
            "digest": digest as Any,
            "translationsCount": translations.count,
            "hasCustomTranslations": hasCustomTranslations
        ])
        return "TagTranslator(\(params))"
    }
}
