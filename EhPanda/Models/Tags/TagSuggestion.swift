//
//  TagSuggestion.swift
//  EhPanda
//
//  Created by xioxin on 2022/2/15.
//

import SwiftUI

struct TagSuggestion: Equatable, Hashable, Identifiable {
    let id: UUID = .init()
    let tag: TagTranslation
    let weight: Float
    let keyRange: Range<String.Index>?
    let valueRange: Range<String.Index>?
    let keyword: String

    var displayKey: String {
        let namespace = tag.namespace.rawValue
        let leftSideString = leftSideString(of: keyRange, string: tag.key)
        var middleString = middleString(of: keyRange, string: tag.key)
        let rightSideString = rightSideString(of: keyRange, string: tag.key)
        middleString = middleString.isEmpty ? middleString : middleString.linkStyled
        return [namespace, ":", leftSideString, middleString, rightSideString].joined()
    }
    var displayValue: String {
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
