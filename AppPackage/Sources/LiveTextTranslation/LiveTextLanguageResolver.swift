import Foundation
import NaturalLanguage
import Translation

/// The language a page is translated from and the one it is translated into.
public struct LiveTextLanguagePair: Hashable, Sendable {
    public let source: Locale.Language
    public let target: Locale.Language

    public init(source: Locale.Language, target: Locale.Language) {
        self.source = source
        self.target = target
    }
}

/// What translating a page takes, decided from its text and the reader's languages.
public enum LiveTextTranslationRoute: Equatable, Sendable {
    /// Translate with the models already on the device.
    case translate(LiveTextLanguagePair)
    /// Translate once the system has downloaded the pair's models, which it asks the reader about.
    case download(LiveTextLanguagePair)
    /// Leave the page as it is: it is already in the reader's language.
    case untranslated
    case failed(LiveTextTranslationFailure)
}

public enum LiveTextLanguageResolver {
    /// How to translate a page holding `texts`.
    ///
    /// The source is the gallery's language when that names one language (`candidates`, the codes
    /// Live Text read the page in); otherwise the language the page's text is written in, chosen
    /// among the candidates when there are several, as Chinese has two scripts. The target is the
    /// reader's most preferred language; a page already in it is left as it is. When the framework
    /// cannot translate into that language, the reader's next preferred one it can is used.
    public static func route(
        for texts: [LiveTextSourceText],
        candidates: [Locale.Language],
        client: LiveTextTranslationClient
    ) async -> LiveTextTranslationRoute {
        let pageText = texts.map(\.text).joined(separator: "\n")
        guard let source = sourceLanguage(of: pageText, candidates: candidates) else {
            return .failed(.unidentifiedLanguage)
        }
        let preferred = client.preferredLanguages()
        guard let mostPreferred = preferred.first, !source.reads(as: mostPreferred) else {
            return .untranslated
        }
        for target in preferred where !source.reads(as: target) {
            let pair = LiveTextLanguagePair(source: source, target: target)
            switch await client.availability(source, target) {
            case .installed:
                return .translate(pair)
            case .supported:
                return .download(pair)
            case .unsupported:
                continue
            @unknown default:
                continue
            }
        }
        return .failed(.unsupportedLanguages(source: source, target: mostPreferred))
    }

    /// The language `text` is written in, among `candidates` when there are any.
    ///
    /// Without candidates the recognizer must be at least even-odds sure, so a page of names or sound
    /// effects is not translated from a guess.
    static func sourceLanguage(of text: String, candidates: [Locale.Language]) -> Locale.Language? {
        if candidates.count == 1 {
            return candidates.first
        }
        let recognizer = NLLanguageRecognizer()
        recognizer.languageConstraints = candidates.map(NLLanguage.init(translationLanguage:))
        recognizer.processString(text)
        let hypothesis = recognizer.languageHypotheses(withMaximum: 1).max(by: { $0.value < $1.value })
        guard let hypothesis else {
            return candidates.first
        }
        guard !candidates.isEmpty || hypothesis.value >= 0.5 else {
            return nil
        }
        return Locale.Language(identifier: hypothesis.key.rawValue)
    }
}

extension Locale.Language {
    /// Whether text in this language reads as text in `other` does: the same language in the same
    /// script, whatever the region. American and British English read alike; Simplified and
    /// Traditional Chinese do not.
    func reads(as other: Locale.Language) -> Bool {
        languageCode == other.languageCode && maximalScript == other.maximalScript
    }

    /// Whether the language's script has upper and lower case.
    var writesInCase: Bool {
        guard let script = maximalScript else {
            return false
        }
        return [Locale.Script.latin, .cyrillic, .greek, .armenian].contains(script)
    }

    private var maximalScript: Locale.Script? {
        Locale.Language(identifier: maximalIdentifier).script
    }
}

private extension NLLanguage {
    /// The recognizer's language for a translation language: Chinese by script, others by language.
    init(translationLanguage language: Locale.Language) {
        if language.languageCode == .chinese,
           let script = Locale.Language(identifier: language.maximalIdentifier).script {
            self.init(rawValue: "zh-\(script.identifier)")
        } else {
            self.init(rawValue: language.languageCode?.identifier ?? language.minimalIdentifier)
        }
    }
}
