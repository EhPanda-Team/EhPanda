import Foundation

public struct TagSuggestion: Equatable, Hashable, Identifiable, Sendable {
    public init(
        tag: TagTranslation,
        weight: Float,
        keyRange: Range<String.Index>? = nil,
        valueRange: Range<String.Index>? = nil,
        originalKeyword: String,
        matchesNamespace: Bool
    ) {
        self.tag = tag
        self.weight = weight
        self.keyRange = keyRange
        self.valueRange = valueRange
        self.originalKeyword = originalKeyword
        self.matchesNamespace = matchesNamespace
    }
    public let id: UUID = .init()
    public let tag: TagTranslation
    public let weight: Float
    public let keyRange: Range<String.Index>?
    public let valueRange: Range<String.Index>?
    public let originalKeyword: String
    public let matchesNamespace: Bool
}
