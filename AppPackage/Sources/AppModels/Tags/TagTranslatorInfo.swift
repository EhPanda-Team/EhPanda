import Foundation

/// Lightweight, persisted metadata about the tag-translation database.
///
/// The translation dictionary itself is *not* persisted — it is rebuilt in memory at launch
/// from a cached raw JSON file (see the tag-translator fetch/import flow). Only this small
/// envelope is stored, so the app can decide on launch whether a fresh download is due
/// (`updatedDate`) and which locale/customization is active without holding the full table
/// in the defaults domain.
///
/// The manual `init(from:)` decodes tolerantly so future additive changes never invalidate
/// an existing persisted value.
public struct TagTranslatorInfo: Codable, Equatable, Sendable {
    public init(
        language: TranslatableLanguage? = nil,
        updatedDate: Date = .distantPast,
        hasCustomTranslations: Bool = false
    ) {
        self.language = language
        self.updatedDate = updatedDate
        self.hasCustomTranslations = hasCustomTranslations
    }
    public var language: TranslatableLanguage?
    public var updatedDate: Date
    public var hasCustomTranslations: Bool
}

// MARK: Manually decode
extension TagTranslatorInfo {
    public init(from decoder: Decoder) {
        let container = try? decoder.container(keyedBy: CodingKeys.self)
        language = (try? container?.decodeIfPresent(TranslatableLanguage.self, forKey: .language)) ?? nil
        updatedDate = (try? container?.decodeIfPresent(Date.self, forKey: .updatedDate)) ?? .distantPast
        hasCustomTranslations = (try? container?.decodeIfPresent(Bool.self, forKey: .hasCustomTranslations)) ?? false
    }
}
