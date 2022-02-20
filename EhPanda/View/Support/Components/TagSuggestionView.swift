//
//  TagSuggestionView.swift
//  EhPanda
//
//  Created by xioxin on 2022/2/15.
//

import SwiftUI

struct TagSuggestionView: View {
    @Binding private var keyword: String
    @StateObject private var translationHandler = TagTranslationHandler()

    init(keyword: Binding<String>) {
        _keyword = keyword
    }

    var body: some View {
        ForEach(translationHandler.suggestions) { suggestion in
            HStack {
                Image(systemSymbol: .magnifyingglass)
                VStack {
                    Text(suggestion.displayValue)
                    Text(suggestion.displayKey)
                }
            }
            .onTapGesture { translationHandler.autoComplete(suggestion: suggestion, keyword: &keyword) }
        }
        .onChange(of: keyword, perform: translationHandler.analyzeKeyword)
    }
}

final class TagTranslationHandler: ObservableObject {
    @Published var suggestions = [TagSuggestion]()
    private var autoCompletionOffset = 0

    func analyzeKeyword(_ keyword: String) {
        let keyword = keyword.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
//        self.keyword = keyword

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
            suggestions = getSuggestions(translations: [], keyword: last)
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
            .sorted { $1.weight > $0.weight }
    }
}
