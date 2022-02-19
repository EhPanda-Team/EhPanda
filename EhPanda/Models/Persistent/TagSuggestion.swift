//
//  TagSuggestion.swift
//  EhPanda
//
//  Created by xioxin on 2022/2/15.
//

import SwiftUI

struct TagSuggestion: Identifiable {
    let id: UUID = .init()
    let tag: TagTranslation
    let weight: Float
    let keyRange: Range<String.Index>?
    let valueRange: Range<String.Index>?

    var displayKey: LocalizedStringKey {
        let namespace = tag.namespace.rawValue
        let leftSideString = leftSideString(of: keyRange, string: tag.key)
        let middleString = middleString(of: keyRange, string: tag.key)
        let rightSideString = rightSideString(of: keyRange, string: tag.key)
        return [namespace, ":", leftSideString, middleString.bold, rightSideString].joined().localizedKey
    }
    var displayValue: LocalizedStringKey {
        let leftSideString = leftSideString(of: valueRange, string: tag.value)
        let middleString = middleString(of: valueRange, string: tag.value)
        let rightSideString = rightSideString(of: valueRange, string: tag.value)
        return [leftSideString, middleString.bold, rightSideString].joined().localizedKey
    }

    private func leftSideString(of range: Range<String.Index>?, string: String) -> String {
        guard let range = range else { return string }
        return .init(string[string.startIndex..<range.lowerBound])
    }
    private func middleString(of range: Range<String.Index>?, string: String) -> String {
        guard let range = range else { return "" }
        return .init(string[range])
    }
    private func rightSideString(of range: Range<String.Index>?, string: String) -> String {
        guard let range = range else { return "" }
        return .init(string[range.upperBound..<string.endIndex])
    }
}
