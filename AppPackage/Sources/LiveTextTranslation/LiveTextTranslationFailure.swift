import Foundation

/// Why Live Text could not translate a page.
///
/// A page already in the reader's language is not a failure: Live Text shows it as it always has.
/// Neither is a download the reader declined, which the reader decided on.
public enum LiveTextTranslationFailure: Equatable, Sendable {
    /// The page's language could not be told from its text.
    case unidentifiedLanguage
    /// The device cannot translate the page's language into any of the reader's languages;
    /// `target` is the reader's most preferred one.
    case unsupportedLanguages(source: Locale.Language, target: Locale.Language)
    /// The translation itself failed.
    case translationFailed

    /// The kinds of failure, each told to the reader once while Live Text stays on.
    public enum Kind: Hashable, Sendable {
        case unidentifiedLanguage
        case unsupportedLanguages
        case translationFailed
    }

    public var kind: Kind {
        switch self {
        case .unidentifiedLanguage:
            .unidentifiedLanguage
        case .unsupportedLanguages:
            .unsupportedLanguages
        case .translationFailed:
            .translationFailed
        }
    }

    /// The message the reader's toast shows.
    public var caption: LocalizedStringResource {
        switch self {
        case .unidentifiedLanguage:
            .translationFailureUnidentifiedLanguage
        case .unsupportedLanguages(let source, let target):
            .translationFailureUnsupportedLanguages(Self.name(of: source), Self.name(of: target))
        case .translationFailed:
            .translationFailureTranslationFailed
        }
    }

    private static func name(of language: Locale.Language) -> String {
        Locale.current.localizedString(forIdentifier: language.minimalIdentifier) ?? language.minimalIdentifier
    }
}
