//
//  TagTranslationHandler.swift
//  EhPanda
//
//  Created by xioxin on 2022/2/15.
//

import SwiftUI

struct TagTip: View {
    @State var keyword = ""
    @State var suggestions: [TagSuggestion] = []
    @State var autoCompletionOffset: Int = .zero

    func getSuggestions(translations: [TagTranslation], keyword: String) -> [TagSuggestion] {
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

    func setSuggestions(keyword: String) {
        let keyword = keyword.replacingOccurrences(of: "  +", with: " ", options: .regularExpression)
        self.keyword = keyword

        guard let regex = try? NSRegularExpression(pattern: "(\\S+:\".+?\"|\".+?\"|\\S+:\\S+|\\S+)") else { return }
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

    var body: some View {
        VStack {
            HStack {
                TextField("", text: $keyword)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onChange(of: keyword, perform: setSuggestions)
                    .toolbar {
                        ToolbarItem(placement: .keyboard) {
                            HStack {
                                Button("-/+") {}
                                .buttonStyle(.bordered)
                                Spacer()
                                Button("Finish") {}
                                .buttonStyle(.bordered)
                            }
                            .padding(.horizontal, 30)
                        }
                    }
                    .onSubmit{
                        print(keyword)
                    }
                Button("Search") {
                    print(keyword)
                }
                .keyboardShortcut(.defaultAction)
            }
            List(suggestions) { suggestion in
                HStack {
                    VStack {
                        Text(suggestion.displayValue)
                        Spacer()
                        Text(suggestion.displayKey)
                    }
                    .onTapGesture {
                        let endIndex = keyword.index(keyword.endIndex, offsetBy: autoCompletionOffset)
                        keyword = .init(keyword[keyword.startIndex..<endIndex])
                        + suggestion.tag.searchKeyword + " "
                    }
                    Spacer()
                    Text("Exclude")
                        .onTapGesture {
                            let endIndex = keyword.index(keyword.endIndex, offsetBy: autoCompletionOffset)
                            keyword = .init(keyword[keyword.startIndex..<endIndex])
                            + "-" + suggestion.tag.searchKeyword + " "
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }
}
