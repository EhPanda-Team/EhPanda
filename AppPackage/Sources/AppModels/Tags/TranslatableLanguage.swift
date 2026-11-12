import Foundation

public enum TranslatableLanguage: Codable, CaseIterable, Sendable {
    case english
    case japanese
    case korean
    case simplifiedChinese
    case traditionalChinese
}

extension TranslatableLanguage {
    /// The one repository whose releases carry every language as a separate asset.
    public static let repoName = "EhPanda-Team/ehpanda-tag-database"

    public static var current: TranslatableLanguage? {
        guard let preferredLanguage = Locale.preferredLanguages.first else { return nil }
        return matching(preferredLanguage: preferredLanguage)
    }
    /// Parses the identifier rather than searching it, so `kok-IN` is not Korean and a `-u-ca-japanese`
    /// calendar extension is not Japanese. Every Traditional Chinese region, such as `zh-Hant-HK`, reads
    /// the one Taiwan-usage dataset.
    static func matching(preferredLanguage: String) -> TranslatableLanguage? {
        let language = Locale.Language(identifier: preferredLanguage)
        switch language.languageCode {
        case Locale.LanguageCode.english:
            return .english
        case Locale.LanguageCode.japanese:
            return .japanese
        case Locale.LanguageCode.korean:
            return .korean
        case Locale.LanguageCode.chinese:
            let script = Locale.Language(identifier: language.maximalIdentifier).script
            return script == .hanTraditional ? .traditionalChinese : .simplifiedChinese
        default:
            return nil
        }
    }
    public var languageCode: String {
        switch self {
        case .english:
            return "en"
        case .japanese:
            return "ja"
        case .korean:
            return "ko"
        case .simplifiedChinese:
            return "zh-Hans"
        case .traditionalChinese:
            return "zh-Hant"
        }
    }
    public var remoteFilename: String {
        "\(languageCode).json"
    }
    /// Filesystem-safe name for this language's cached raw translation JSON.
    public var cachedTranslationsFilename: String {
        "tagTranslations-\(languageCode).json"
    }
}
