import Foundation

/// Thin, `appStorage`-persisted metadata for the tag-translation table.
///
/// The translations dictionary itself is NOT persisted — it is large, derived, and
/// re-downloadable, so it lives only in memory and is rebuilt at launch from the cached raw JSON
/// (Caches for a remote download, Application Support for a user import). This record remembers just
/// enough to rebuild the right file and to let the update check know what it already has: which
/// language/version is cached and whether a custom import is active.
public struct TagTranslatorInfo: Codable, Equatable, Sendable, SchemaVersioned {
    public init(
        schemaVersion: SchemaVersion<TagTranslatorInfo> = 1,
        language: TranslatableLanguage? = nil,
        updatedDate: Date = .distantPast,
        hasCustomTranslations: Bool = false
    ) {
        self.schemaVersion = schemaVersion
        self.language = language
        self.updatedDate = updatedDate
        self.hasCustomTranslations = hasCustomTranslations
    }
    /// Highest `schemaVersion` this build can decode. Bump when a breaking change lands and add a
    /// custom `init(from:)` that maps the older shape forward.
    public static let currentSchemaVersion = 1
    // A self-validating field: it rejects a newer/downgrade blob on decode (see `SchemaVersion`), which
    // fails the whole decode so Sharing resets to the key default. Synthesized Codable is otherwise
    // untouched, so optional-field tolerance still holds; a field added later must stay optional so old
    // blobs keep decoding.
    public var schemaVersion: SchemaVersion<TagTranslatorInfo>
    public var language: TranslatableLanguage?
    public var updatedDate: Date
    public var hasCustomTranslations: Bool
}
