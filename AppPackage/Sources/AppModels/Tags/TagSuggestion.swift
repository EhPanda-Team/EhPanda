import SwiftUI

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

    public var displayKey: String {
        var namespace = tag.namespace.rawValue
        let leftSideString = leftSideString(of: keyRange, string: tag.key)
        var middleString = middleString(of: keyRange, string: tag.key)
        let rightSideString = rightSideString(of: keyRange, string: tag.key)
        middleString = middleString.isEmpty ? middleString : middleString.linkStyled
        namespace = matchesNamespace ? namespace.linkStyled : namespace
        return [namespace, ":", leftSideString, middleString, rightSideString].joined()
    }
    public var displayValue: String {
        let text = tag.displayValue
        let leftSideString = leftSideString(of: valueRange, string: text)
        var middleString = middleString(of: valueRange, string: text)
        let rightSideString = rightSideString(of: valueRange, string: text)
        middleString = middleString.isEmpty ? middleString : middleString.linkStyled
        return [leftSideString, middleString, rightSideString].joined()
    }

    private func leftSideString(of range: Range<String.Index>?, string: String) -> String {
        guard let range = range, string.endIndex >= range.lowerBound else { return string }
        return .init(string[string.startIndex..<range.lowerBound])
    }
    private func middleString(of range: Range<String.Index>?, string: String) -> String {
        guard let range = range,
              range.upperBound <= string.endIndex,
              range.lowerBound >= string.startIndex
        else { return .init() }
        return .init(string[range])
    }
    private func rightSideString(of range: Range<String.Index>?, string: String) -> String {
        guard let range = range, range.upperBound < string.endIndex else { return .init() }
        return .init(string[range.upperBound..<string.endIndex])
    }
}
