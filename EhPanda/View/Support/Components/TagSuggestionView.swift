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
    private let translations: [TagTranslation]

    @StateObject private var translationHandler = TagTranslationHandler()

    init(keyword: Binding<String>, translations: [TagTranslation]) {
        _keyword = keyword
        self.translations = translations
    }

    var body: some View {
        DoubleHorizontalSuggestionsStack(suggestions: translationHandler.suggestions) { suggestion in
            translationHandler.autoComplete(suggestion: suggestion, keyword: &keyword)
        }
        .onChange(of: keyword) { _ in translationHandler.analyze(text: &keyword, translations: translations) }
    }
}

private struct DoubleHorizontalSuggestionsStack: View {
    private let suggestions: [TagSuggestion]
    private let action: (TagSuggestion) -> Void

    init(suggestions: [TagSuggestion], action: @escaping (TagSuggestion) -> Void) {
        self.suggestions = suggestions
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
                SuggestionCell(suggestion: suggestion) {
                    action(suggestion)
                }
            }
        } else {
            ForEach(doubleSuggestions, id: \.0) { leadingSuggestion, trailingSuggestion in
                HStack(spacing: 30) {
                    SuggestionCell(suggestion: leadingSuggestion) {
                        action(leadingSuggestion)
                    }
                    if let trailingSuggestion = trailingSuggestion {
                        SuggestionCell(suggestion: trailingSuggestion) {
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
    private let action: () -> Void

    init(suggestion: TagSuggestion, action: @escaping () -> Void) {
        self.suggestion = suggestion
        self.action = action
    }

    private var plainText: LocalizedStringKey {
        let text = suggestion.displayValue
        return (MarkdownUtil.ripImage(string: text) ?? text).localizedKey
    }
    private var markdownImageURL: URL? {
        let text = suggestion.displayValue
        if let imageURLString = MarkdownUtil.parseImage(string: text) {
            return .init(string: imageURLString)
        }
        return nil
    }

    var body: some View {
        HStack(spacing: 20) {
            Image(systemSymbol: .magnifyingglass)
            VStack(alignment: .leading) {
                HStack(spacing: 2) {
                    Text(plainText)
                    if let markdownImageURL = markdownImageURL {
                        Image(systemSymbol: .photo).opacity(0)
                            .overlay(KFImage(markdownImageURL).resizable().scaledToFit())
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
    private var autoCompletionOffset = 0

    func analyze(text: inout String, translations: [TagTranslation]) {
        let keyword = text.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        text = keyword

        guard let regex = Defaults.Regex.tagSuggestion else { return }
        let values: [String] = regex.matches(in: keyword, range: .init(location: 0, length: keyword.count))
            .compactMap {
                if let range = Range($0.range, in: keyword) {
                    return .init(keyword[range])
                } else {
                    return nil
                }
            }
        if let last = values.last {
            autoCompletionOffset = 0 - last.count
            suggestions = getSuggestions(translations: translations, keyword: last)
        } else {
            suggestions = []
            autoCompletionOffset = .zero
        }
    }
    func autoComplete(suggestion: TagSuggestion, keyword: inout String) {
        let endIndex = keyword.index(keyword.endIndex, offsetBy: autoCompletionOffset)
        keyword = .init(keyword[keyword.startIndex..<endIndex])
        + suggestion.tag.searchKeyword + " "
    }
    private func getSuggestions(translations: [TagTranslation], keyword: String) -> [TagSuggestion] {
        var keyword = keyword
        var namespace: String?
        let namespaceAbbreviations = TagNamespace.abbreviations

        if let colon = keyword.firstIndex(of: ":") {
            // Requires at least one character before the colon
            if colon >= keyword.index(keyword.startIndex, offsetBy: 1) {
                let key = String(keyword[keyword.startIndex ..< colon])
                if let index = namespaceAbbreviations.firstIndex(where: {
                    $0.caseInsensitiveEqualsTo(key) || $1.caseInsensitiveEqualsTo(key)
                }) {
                    namespace = namespaceAbbreviations[index].key
                    keyword = .init(keyword[keyword.index(colon, offsetBy: 1) ..< keyword.endIndex])
                }
            }
        }

        var translations = translations
        if let namespace = namespace {
            translations = translations.filter { $0.namespace.rawValue == namespace }
        }
        return translations
            .map { $0.getSuggestion(keyword: keyword) }
            .filter { $0.weight > 0 }
            .sorted { $0.weight > $1.weight }
    }
}
