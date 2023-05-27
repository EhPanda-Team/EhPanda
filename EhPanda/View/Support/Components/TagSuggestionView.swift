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
            if DeviceUtil.isPhone {
                Text(L10n.Localizable.Searchable.Title.matchesCount(translationHandler.suggestions.count))
                    .foregroundColor(.secondary)
                    .font(.subheadline)
            }

            let suggestions = translationHandler.suggestions
            ForEach(suggestions.prefix(min(suggestions.count, 10))) { suggestion in
                SuggestionCell(
                    suggestion: suggestion,
                    showsImages: showsImages,
                    action: { translationHandler.autoComplete(suggestion: suggestion, keyword: &keyword) }
                )
            }
            .onChange(of: keyword) { _ in
                translationHandler.analyze(text: &keyword, translations: translations)
            }
        }
    }
}

// MARK: SuggestionCell
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
        if DeviceUtil.isPhone {
            HStack(spacing: 20) {
                Image(systemSymbol: .magnifyingglass)

                VStack(alignment: .leading) {
                    HStack(spacing: 2) {
                        Text(displayValue.localizedKey)

                        if let imageURL = suggestion.tag.valueImageURL, showsImages {
                            Image(systemSymbol: .photo)
                                .opacity(0)
                                .overlay(
                                    KFImage(imageURL)
                                        .resizable()
                                        .scaledToFit()
                                )
                        }
                    }
                    .font(.callout)
                    .lineLimit(1)

                    Text(suggestion.displayKey.localizedKey)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                .allowsHitTesting(false)

                Spacer()
            }
            .contentShape(Rectangle())
            .onTapGesture(perform: action)
        } else {
            (Text(displayValue.localizedKey) + Text("\n") + Text(suggestion.displayKey.localizedKey))
                .searchCompletion(suggestion.tag.searchKeyword)
        }
    }
}

// MARK: TagTranslationHandler
final class TagTranslationHandler: ObservableObject {
    @Published var suggestions = [TagSuggestion]()

    func analyze(text: inout String, translations: [String: TagTranslation]) {
        let keyword = text.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
            .replacingOccurrences(of: "：", with: ":")
        text = keyword
        guard let regex = Defaults.Regex.tagSuggestion else { return }
        let keywords: [String] = regex.matches(in: keyword, range: .init(location: 0, length: keyword.count))
            .compactMap {
                if let range = Range($0.range, in: keyword) {
                    return .init(keyword[range])
                } else {
                    return nil
                }
            }
        var result = [TagSuggestion]()
        var existingWords = Set<String>()
        let lastCompletedTagIndex = keywords.lastIndex(where: { ["\"", "$"].contains($0.last) })
        for index in (lastCompletedTagIndex ?? 0)..<keywords.count {
            let keywordList = keywords[index...]
            if !keywordList.isEmpty {
                let keyword = keywordList.joined(separator: " ")
                getSuggestions(translations: translations, keyword: keyword).forEach {
                    if !existingWords.contains($0.tag.searchKeyword) {
                        existingWords.insert($0.tag.searchKeyword)
                        result.append($0)
                    }
                }
            }
        }
        suggestions = result
    }
    func autoComplete(suggestion: TagSuggestion, keyword: inout String) {
        let endIndex = keyword.index(keyword.endIndex, offsetBy: 0 - suggestion.originalKeyword.count)
        keyword = .init(keyword[keyword.startIndex..<endIndex]) + suggestion.tag.searchKeyword + " "
    }
    private func getSuggestions(translations: [String: TagTranslation], keyword: String) -> [TagSuggestion] {
        let originalKeyword = keyword
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
            // Returns suggestion based on namespace only
            return translations
                .map {
                    .init(
                        tag: $0.value, weight: 0, keyRange: nil, valueRange: nil,
                        originalKeyword: originalKeyword, matchesNamespace: true
                    )
                }
        } else {
            // Returns suggestion based on namespace and keyword
            return translations
                .map {
                    $0.value.getSuggestion(
                        keyword: keyword,
                        originalKeyword: originalKeyword,
                        matchesNamespace: namespace != nil
                    )
                }
                .filter { $0.weight > 0 }
                .sorted { $0.weight > $1.weight }
        }
    }
}
