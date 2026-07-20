import AppTools
import AppModels
import Foundation

extension TagTranslator {
    public func lookup(word: String, returnOriginal: Bool) -> TagTranslationLookup {
        guard !returnOriginal else { return .init(text: word, translation: nil) }
        let (lhs, rhs) = word.stringsBesideColon

        var key = rhs
        if let lhs = lhs {
            key = lhs + rhs
        }
        guard let translation = translations[key] else { return .init(text: word, translation: nil) }

        var result = translation.displayValue
        if let lhs = lhs {
            result = [lhs, ":", result].joined()
        }
        return .init(text: result, translation: translation)
    }
}
