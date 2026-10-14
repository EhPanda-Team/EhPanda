public import ComposableArchitecture
public import Foundation
public import Translation

/// Language preferences and system support used to select each page's translation pair.
/// Translation itself runs in the reader's SwiftUI-owned session, which can request model downloads.
@DependencyClient
public struct LiveTextTranslationClient: Sendable {
    /// The reader's languages, most preferred first, following a per-app language.
    public var preferredLanguages: @Sendable () -> [Locale.Language] = { [] }
    /// Whether the device can translate `source` into `target`, and whether it has the models to.
    public var availability: @Sendable (
        _ source: Locale.Language,
        _ target: Locale.Language
    ) async -> LanguageAvailability.Status = { _, _ in .unsupported }
}

extension LiveTextTranslationClient: DependencyKey {
    public static let liveValue = Self(
        preferredLanguages: {
            Locale.preferredLanguages.map(Locale.Language.init(identifier:))
        },
        availability: { source, target in
            await LanguageAvailability().status(from: source, to: target)
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
