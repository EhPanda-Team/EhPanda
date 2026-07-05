import Foundation

public enum TranslatableLanguage: Codable, CaseIterable, Sendable {
    case english
    case japanese
    case simplifiedChinese
    case traditionalChinese
}

extension TranslatableLanguage {
    public static var current: TranslatableLanguage? {
        guard let preferredLanguage = Locale.preferredLanguages.first,
              let translatableLanguage = TranslatableLanguage.allCases.compactMap({ lang in
                preferredLanguage.contains(lang.languageCode) ? lang : nil
              }).first else { return nil }
        return translatableLanguage
    }
    public var languageCode: String {
        switch self {
        case .english:
            return "en"
        case .japanese:
            return "ja"
        case .simplifiedChinese:
            return "zh-Hans"
        case .traditionalChinese:
            return "zh-Hant"
        }
    }
    public var repoName: String {
        switch self {
        case .english:
            return "EhPanda-Team/EhTagTranslation_Database_EN"
        case .japanese:
            return "EhPanda-Team/EhTagTranslation_Database_JPN"
        case .simplifiedChinese, .traditionalChinese:
            return "EhTagTranslation/Database"
        }
    }
    public var remoteFilename: String {
        switch self {
        case .english, .japanese, .simplifiedChinese, .traditionalChinese:
            return "db.raw.json"
        }
    }
    /// Filesystem-safe name for this language's cached raw translation JSON. Keyed on
    /// `languageCode` (not `repoName`, which contains `/`), so each language gets its own file —
    /// `simplifiedChinese`/`traditionalChinese` share a repo but need distinct caches (the latter
    /// is OpenCC-converted).
    public var cachedTranslationsFilename: String {
        "tagTranslations-\(languageCode).json"
    }
}
