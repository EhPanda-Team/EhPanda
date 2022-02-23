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
    private let showsImages: Bool
    private let isEnabled: Bool

    @StateObject private var translationHandler = TagTranslationHandler()

    init(keyword: Binding<String>, translations: [TagTranslation], showsImages: Bool, isEnabled: Bool) {
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
                let key = String(keyword[keyword.startIndex..<colon])
                if let index = namespaceAbbreviations.firstIndex(where: {
                    $0.caseInsensitiveEqualsTo(key) || $1.caseInsensitiveEqualsTo(key)
                }) {
                    namespace = namespaceAbbreviations[index].key
                    keyword = .init(keyword[keyword.index(colon, offsetBy: 1)..<keyword.endIndex])
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
