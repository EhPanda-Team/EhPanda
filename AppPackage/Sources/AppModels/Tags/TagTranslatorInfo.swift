import Foundation

/// Thin, `appStorage`-persisted metadata for the tag-translation table.
///
/// The translations dictionary itself is NOT persisted — it is large, derived, and
/// re-downloadable, so it lives only in memory and is rebuilt at launch from the cached raw JSON
/// (Caches for a remote download, Application Support for a user import). This record remembers just
/// enough to rebuild the right file and to let the update check know what it already has: which
/// language/version is cached and whether a custom import is active.
public struct TagTranslatorInfo: Codable, Equatable, Sendable {
    public init(
        schemaVersion: Int = 1,
        language: TranslatableLanguage? = nil,
        updatedDate: Date = .distantPast,
        hasCustomTranslations: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.language = language
        self.updatedDate = updatedDate
        self.hasCustomTranslations = hasCustomTranslations
    }
    // Version anchor for a future breaking migration. All current fields decode strictly (synthesized
    // Codable); a field added later must stay optional so an old blob still decodes.
    public var schemaVersion: Int
    public var language: TranslatableLanguage?
    public var updatedDate: Date
    public var hasCustomTranslations: Bool
}
