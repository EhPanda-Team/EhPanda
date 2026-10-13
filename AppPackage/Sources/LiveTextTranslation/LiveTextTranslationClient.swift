import ComposableArchitecture
import Foundation
import Translation

/// Apple's on-device translation, as Live Text uses it.
///
/// Translation runs only with models already on the device: a session made here cannot download
/// any. Downloading goes through the system's own prompt, which only SwiftUI's `translationTask` can
/// show. Availability and translation both use the system's default strategy, so a pair reported as
/// installed is the pair a session then translates with.
@DependencyClient
public struct LiveTextTranslationClient: Sendable {
    /// The reader's languages, most preferred first, following a per-app language.
    public var preferredLanguages: @Sendable () -> [Locale.Language] = { [] }
    /// Whether the device can translate `source` into `target`, and whether it has the models to.
    public var availability: @Sendable (
        _ source: Locale.Language,
        _ target: Locale.Language
    ) async -> LanguageAvailability.Status = { _, _ in .unsupported }
    /// The translation of each text, by its group, with the pair's installed models.
    public var translate: @Sendable (
        _ texts: [LiveTextSourceText],
        _ pair: LiveTextLanguagePair
    ) async throws -> [UUID: String]
}

extension LiveTextTranslationClient: DependencyKey {
    public static let liveValue = Self(
        preferredLanguages: {
            Locale.preferredLanguages.map(Locale.Language.init(identifier:))
        },
        availability: { source, target in
            await LanguageAvailability().status(from: source, to: target)
        },
        translate: { texts, pair in
            let session = TranslationSession(installedSource: pair.source, target: pair.target)
            let requests = texts.map { text in
                TranslationSession.Request(sourceText: text.text, clientIdentifier: text.groupID.uuidString)
            }
            var translations = [UUID: String]()
            for response in try await session.translations(from: requests) {
                guard let groupID = response.clientIdentifier.flatMap(UUID.init(uuidString:)),
                      translations[groupID] == nil
                else {
                    continue
                }
                translations[groupID] = response.targetText
            }
            return translations
        }
    )
    public static let testValue = Self()
}

extension DependencyValues {
    public var liveTextTranslationClient: LiveTextTranslationClient {
        get { self[LiveTextTranslationClient.self] }
        set { self[LiveTextTranslationClient.self] = newValue }
    }
}
