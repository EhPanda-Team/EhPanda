#if DEBUG
public import AppModels
public import Foundation
import LiveTextTranslation

extension LiveTextCapture {
    /// Recorded model responses, bound to the normalized text and IDs of the saved recognition.
    public struct TranslationEntry: Codable, Equatable, Sendable {
        public let id: UUID
        public let source: String
        public let target: String
    }

    public struct Translation: Codable, Equatable, Sendable {
        public let sourceLanguage: String
        public let targetLanguage: String
        public let entries: [TranslationEntry]

        public func matches(_ groups: [LiveTextGroup]) -> Bool {
            let pair = LiveTextLanguagePair(
                source: Locale.Language(identifier: sourceLanguage),
                target: Locale.Language(identifier: targetLanguage)
            )
            let texts = groups.compactMap(LiveTextSourceText.init(group:)).map({ $0.prepared(for: pair) })
            return !sourceLanguage.isEmpty && !targetLanguage.isEmpty && sourceLanguage != targetLanguage
                && entries.count == texts.count && Set(entries.map(\.id)).count == entries.count
                && entries.allSatisfy { entry in
                    !entry.target.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        && texts.contains(where: { $0.groupID == entry.id && $0.text == entry.source })
                }
        }
    }
}
#endif
