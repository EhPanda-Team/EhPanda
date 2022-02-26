//
//  TagSuggestionView.swift
//  EhPanda
//
//  Created by xioxin on 2022/2/15.
//

import SwiftUI
import Kingfisher

struct TagSuggestionView: View {
    @Binding private var keyword: String
    private let translations: [String: TagTranslation]
    private let showsImages: Bool
    private let isEnabled: Bool

    @StateObject private var translationHandler = TagTranslationHandler()

    init(keyword: Binding<String>, translations: [String: TagTranslation], showsImages: Bool, isEnabled: Bool) {
        _keyword = keyword
        self.translations = translations
        self.showsImages = showsImages
        self.isEnabled = isEnabled
    }

    var body: some View {
        if isEnabled {
            DoubleHorizontalSuggestionsStack(
                suggestions: translationHandler.suggestions, showsImages: showsImages,
                action: { translationHandler.autoComplete(suggestion: $0, keyword: &keyword) }
            )
            .onChange(of: keyword) { _ in translationHandler.analyze(text: &keyword, translations: translations) }
        }
    }
}

private struct DoubleHorizontalSuggestionsStack: View {
    private let suggestions: [TagSuggestion]
    private let showsImages: Bool
    private let action: (TagSuggestion) -> Void

    init(suggestions: [TagSuggestion], showsImages: Bool, action: @escaping (TagSuggestion) -> Void) {
        self.suggestions = suggestions
        self.showsImages = showsImages
        self.action = action
    }

    var singleSuggestions: [TagSuggestion] {
        .init(suggestions.prefix(min(suggestions.count, 10)))
    }
    var doubleSuggestions: [(TagSuggestion, TagSuggestion?)] {
        suggestions.enumerated().compactMap { (index, suggestion) in
            if index < 20, index % 2 == 0 {
                if index + 1 < suggestions.count {
                    return (suggestion, suggestions[index + 1])
                } else {
                    return (suggestion, nil)
                }
            } else {
                return nil
            }
        }
    }

    var body: some View {
        if !DeviceUtil.isPad {
            ForEach(singleSuggestions) { suggestion in
                SuggestionCell(suggestion: suggestion, showsImages: showsImages) {
                    action(suggestion)
                }
            }
        } else {
            ForEach(doubleSuggestions, id: \.0) { leadingSuggestion, trailingSuggestion in
                HStack(spacing: 30) {
                    SuggestionCell(suggestion: leadingSuggestion, showsImages: showsImages) {
                        action(leadingSuggestion)
                    }
                    if let trailingSuggestion = trailingSuggestion {
                        SuggestionCell(suggestion: trailingSuggestion, showsImages: showsImages) {
                            action(trailingSuggestion)
                        }
                    }
                }
            }
        }
    }
}

private struct SuggestionCell: View {
    private let suggestion: TagSuggestion
    private let showsImages: Bool
    private let action: () -> Void

    init(suggestion: TagSuggestion, showsImages: Bool, action: @escaping () -> Void) {
        self.suggestion = suggestion
        self.showsImages = showsImages
        self.action = action
    }

    private var displayValue: String {
        let value = suggestion.displayValue
        return showsImages ? value : value.emojisRipped
    }

    var body: some View {
        HStack(spacing: 20) {
            Image(systemSymbol: .magnifyingglass)
            VStack(alignment: .leading) {
                HStack(spacing: 2) {
                    Text(displayValue.localizedKey)
                    if let imageURL = suggestion.tag.valueImageURL, showsImages {
                        Image(systemSymbol: .photo).opacity(0)
                            .overlay(KFImage(imageURL).resizable().scaledToFit())
                    }
                }
                .font(.callout).lineLimit(1)
                Text(suggestion.displayKey.localizedKey).font(.caption).foregroundColor(.secondary).lineLimit(1)
            }
            .allowsHitTesting(false)
            Spacer()
        }
        .contentShape(Rectangle())
        .onTapGesture(perform: action)
    }
}

final class TagTranslationHandler: ObservableObject {
    @Published var suggestions = [TagSuggestion]()

    func analyze(text: inout String, translations: [String: TagTranslation]) {
        text = text.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "：", with: ":", options: .regularExpression)
        let keyword = text
        guard let regex = Defaults.Regex.tagSuggestion else { return }
        let values: [String] = regex.matches(in: keyword, range: .init(location: 0, length: keyword.count))
            .compactMap {
                if let range = Range($0.range, in: keyword) {
                    return .init(keyword[range])
                } else {
                    return nil
                }
            }
        var result: [TagSuggestion] = []
        var used: Set<String> = []
        let lastFillTagIndex = values.lastIndex {
            let endChar = $0[$0.index(before: $0.endIndex)]
            return endChar == "\"" || endChar == "$"
        } ?? -1
        for index in (lastFillTagIndex + 1)..<values.count {
            let keywordList = values[index...]
            if !keywordList.isEmpty {
                let keyword = keywordList.joined(separator: " ")
                let subSuggestions = getSuggestions(translations: translations, keyword: keyword)
                subSuggestions.forEach{
                    if used.contains($0.tag.searchKeyword) {
                        return
                    }
                    used.insert($0.tag.searchKeyword)
                    result.append($0)
                }
            }
        }
        suggestions = result
    }
    func autoComplete(suggestion: TagSuggestion, keyword: inout String) {
        let endIndex = keyword.index(keyword.endIndex, offsetBy: 0 - suggestion.term.count)
        keyword = .init(keyword[keyword.startIndex..<endIndex])
        + suggestion.tag.searchKeyword + " "
    }
    private func getSuggestions(translations: [String: TagTranslation], keyword: String) -> [TagSuggestion] {
        let term = keyword
        var keyword = keyword
        var namespace: String?
        let namespaceAbbreviations = TagNamespace.abbreviations

        if let colon = keyword.firstIndex(of: ":") {
            let key = String(keyword[keyword.startIndex..<colon])
            if let index = namespaceAbbreviations.firstIndex(where: {
                $0.caseInsensitiveEqualsTo(key) || $1.caseInsensitiveEqualsTo(key)
            }) {
                namespace = namespaceAbbreviations[index].key
                keyword = .init(keyword[keyword.index(colon, offsetBy: 1)..<keyword.endIndex])
            }
        }

        var translations = translations
        if let namespace = namespace {
            translations = translations.filter { $0.value.namespace.rawValue == namespace }
        }
        if namespace != nil && keyword.isEmpty {
            return translations
                .map {
                    .init(tag: $0, weight: 0, keyRange: nil, valueRange: nil, term: term, matchNamespace: true)
                }
        }
        return translations
            .map { $0.getSuggestion(keyword: keyword, term: term, matchNamespace: namespace != nil) }
            .filter { $0.weight > 0 }
            .sorted { $0.weight > $1.weight }
    }
}
