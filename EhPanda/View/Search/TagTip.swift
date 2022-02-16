//
//  TagTip.swift
//  EhPanda
//
//  Created by xioxin on 2022/2/15.
//

import SwiftUI

let shortNsDic: [String: String] = [
    "reclass": "r",
    "language": "l",
    "parody": "p",
    "character": "c",
    "group": "g",
    "artist": "a",
    "cosplayer": "cos",
    "male": "m",
    "female": "f",
    "mixed": "x",
    "other": "o",
    "temp": ""
]

let namespaceScore: [String: Double] = [
    "other": 10,
    "female": 9,
    "male": 8.5,
    "mixed": 8,
    "language": 2,
    "artist": 2.5,
    "cosplayer": 2.4,
    "group": 2.2,
    "parody": 3.3,
    "character": 2.8,
    "reclass": 1,
    "temp": 0.1
]

struct TagItem: Identifiable {
    var id: UUID = UUID()
    var namespace: String
    var key: String
    var name: String

    var shortNamespace: String {
        shortNsDic[namespace] ?? namespace
    }

    var searchTerm: String {
        let namespace = shortNamespace.isEmpty ? "" : "\(shortNamespace):"
        let keyword = key.contains(" ") ? "\"\(key)$\"" : "\(key)$"
        return namespace + keyword
    }

    func markTag(search: String) {}

    func getMatchScore(keyword: String) -> TagSuggestion {
        let namespaceScore = namespaceScore[namespace] ?? 0.0
        var score: Double = 0.0
        let key = key.lowercased()
        let keyRange = key.range(of: keyword)
        if let range = keyRange {
            score += namespaceScore
            * Double(search.count + 1)
            / Double(key.count)
            * (range.contains(key.startIndex) ? 2.0 : 1.0)
        }

        let name = name.lowercased()
        let nameRange = name.range(of: keyword)
        if let range = nameRange {
            score += namespaceScore
            * Double(search.count + 1)
            / Double(name.count)
            * (range.contains(name.startIndex) ? 2.0 : 1.0)
        }
        return TagSuggestion(tag: self, score: score, keyRange: keyRange, nameRange: nameRange)
    }
}

struct TagSuggestion: Identifiable {
    var id: UUID = UUID()
    var tag: TagItem
    var score: Double
    var keyRange: Range<String.Index>?
    var nameRange: Range<String.Index>?

    var keyMatchLeft: String {
        leftSideString(of: keyRange, string: tag.key)
    }

    var keyMatchFocal: String {
        middleString(of: keyRange, string: tag.key)
    }

    var keyMatchRight: String {
        rightSideString(of: keyRange, string: tag.key)
    }

    var nameMatchLeft: String {
        leftSideString(of: nameRange, string: tag.name)
    }

    var nameMatchFocal: String {
        middleString(of: nameRange, string: tag.name)
    }

    var nameMatchRight: String {
        rightSideString(of: nameRange, string: tag.name)
    }

    func leftSideString(of range: Range<String.Index>?, string: String) -> String {
        guard let range = range else { return string }
        return .init(string[string.startIndex..<range.lowerBound])
    }

    func middleString(of range: Range<String.Index>?, string: String) -> String {
        guard let range = range else { return "" }
        return .init(string[range])
    }

    func rightSideString(of range: Range<String.Index>?, string: String) -> String {
        guard let range = range else { return "" }
        return .init(string[range.upperBound..<string.endIndex])
    }
}

extension Array where Element == TagItem {
    func getSuggests(_ term: String) -> [TagSuggestion] {
        let term = term.lowercased()
        var sTerm = term
        var onlyNs: String?
        if let col = term.firstIndex(of: ":") {
            // Requires at least one character before the colon
            if col >= term.index(term.startIndex, offsetBy: 1) {
                let namespace = String(term[term.startIndex ..< col])
                if let index = shortNsDic.index(forKey: namespace) {
                    onlyNs = shortNsDic[index].key
                }
                if let index = shortNsDic.firstIndex(where: {
                    $0 == namespace || $1 == namespace
                }) {
                    onlyNs = shortNsDic[index].key
                    sTerm = String(term[term.index(col, offsetBy: 1) ..< term.endIndex])
                }
            }
        }

        var tagList = self
        if onlyNs != nil {
            tagList = tagList.filter { $0.namespace == onlyNs}
        }

        let suggestions = tagList
            .compactMap { $0.getMatchScore(keyword: sTerm) }
            .filter{$0.score > 0}
            .sorted { $1.score > $0.score }

        print(suggestions)
        return suggestions
    }
}

let allTagList: [TagItem] = [
    TagItem(namespace: "language", key: "chinese", name: "中文"),
    TagItem(namespace: "language", key: "english", name: "英语"),
    TagItem(namespace: "female", key: "loli", name: "萝莉")
]

func pregReplace(_ text: String, pattern: String, with: String, options: NSRegularExpression.Options = []) -> String? {
    let regex = try? NSRegularExpression(pattern: pattern, options: options)
    return regex?.stringByReplacingMatches(
        in: text, options: [], range: .init(location: 0, length: text.count), withTemplate: with
    )
}

struct TagTip: View {
    @State var input = ""
    @State var suggests: [TagSuggestion] = []
    @State var term: String = ""

    func search(_ value: String) {
        guard let value = pregReplace(value, pattern: "  +", with: " ") else { return }
        input = value
        guard let regex = try? NSRegularExpression(pattern: "(\\S+:\".+?\"|\".+?\"|\\S+:\\S+|\\S+)") else { return }
        let matchs = regex.matches(in: value, options: [], range: .init(location: 0, length: value.count))
        let values: [String] = matchs.compactMap {
            String(value[Range($0.range, in: value)!])
        }
        print(values)
        if let last = values.last {
            term = last
            suggests = allTagList.getSuggests(last)
        } else {
            suggests = []
            term = ""
        }
    }

    var body: some View {
        VStack {
            HStack {
                TextField("", text: $input)
                    .textFieldStyle(.roundedBorder)
                    .padding()
                    .onChange(of: input) { newValue in
                        search(newValue)
                        // autocomplete.autocomplete(input)
                    }
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
                        print(input)
                    }
                Button("Search"){
                    print(input)
                }
                .keyboardShortcut(.defaultAction)
            }
            List(suggests) { suggestion in
                HStack {
                    VStack {
                        HStack(spacing: 0.0) {
                            Text(suggestion.nameMatchLeft).font(.body)
                            Text(suggestion.nameMatchFocal).background(Color.red).font(.body)
                            Text(suggestion.nameMatchRight).font(.body)
                        }
                        Spacer()
                        HStack(spacing: 0.0) {
                            Text(suggestion.tag.namespace).font(.caption)
                            Text(":")
                            Text(suggestion.keyMatchLeft).font(.caption)
                            Text(suggestion.keyMatchFocal).background(Color.red).font(.caption)
                            Text(suggestion.keyMatchRight).font(.caption)
                        }
                    }
                    .onTapGesture {
                        input = String(
                            input[input.startIndex..<input.index(input.endIndex, offsetBy: 0 - term.count)]
                        )
                        + suggestion.tag.searchTerm + " "
                    }
                    Spacer()
                    Text("Exclude")
                        .onTapGesture {
                            input = String(
                                input[input.startIndex..<input.index(input.endIndex, offsetBy: 0 - term.count)]
                            )
                            + "-" + suggestion.tag.searchTerm + " "
                        }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
    }
}
