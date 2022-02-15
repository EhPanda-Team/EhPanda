//
//  TagTip.swift
//  Shared
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
    "temp": "",
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
    "temp": 0.1,
]


struct TagItem: Identifiable {
    var id: UUID = UUID()
    var namespace: String
    var key: String
    var name: String
    
    var shortNamespace: String {
        get { shortNsDic[namespace] ?? namespace }
    }
    
    var searchTerm: String {
        get {
            let ns = shortNamespace
            let nsP = ns != "" ? "\(ns):" : ""
            let search = key.contains(" ") ? "\"\(key)$\"" : "\(key)$"
            return nsP + search
        }
    }
    
    func markTag(search: String) {
        
    }
    
    func getMatchScore(search: String) -> TagSuggestion {
        let nsScore = namespaceScore[namespace] ?? 0.0
        var score: Double = 0.0
        let key = key.lowercased()
        let keyRange = key.range(of: search)
        if let range = keyRange {
            score += nsScore * Double(search.count + 1) / Double(key.count) * (range.contains(key.startIndex) ? 2.0 : 1.0)
        }
        
        let cn = name.lowercased()
        let nameRange = cn.range(of: search);
        if let range = nameRange {
            score += nsScore *  Double(search.count + 1) / Double(cn.count) * (range.contains(cn.startIndex) ? 2.0 : 1.0)
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
        get { _rangeTextL(tag.key, keyRange) }
    }
    
    var keyMatchFocal: String {
        get { _rangeTextC(tag.key, keyRange) }
    }
    
    var keyMatchRight: String {
        get { _rangeTextR(tag.key, keyRange) }
    }
    
    var nameMatchLeft: String {
        get { _rangeTextL(tag.name, nameRange) }
    }
    
    var nameMatchFocal: String {
        get { _rangeTextC(tag.name, nameRange) }
    }
    
    var nameMatchRight: String {
        get { _rangeTextR(tag.name, nameRange) }
    }
    
    
    func _rangeTextL(_ str: String,_ range: Range<String.Index>?) -> String {
        guard let range = range else { return str }
        return String(str[str.startIndex..<range.lowerBound])
    }
    
    func _rangeTextC(_ str: String, _ range: Range<String.Index>?) -> String {
        guard let range = range else { return "" }
        return String(str[range])
    }
    
    func _rangeTextR(_ str: String, _ range: Range<String.Index>?) -> String {
        guard let range = range else { return "" }
        return String(str[range.upperBound..<str.endIndex])
    }
    
    
}


extension Array where Element == TagItem {
    func getSuggests(_ term: String) -> [TagSuggestion] {
        let term = term.lowercased()
        var sTerm = term
        var onlyNs: String?
        if let col = term.firstIndex(of: ":") {
            // 冒号前至少有一个字符
            if col >= term.index(term.startIndex, offsetBy: 1) {
                let ns = String(term[term.startIndex ..< col])
                if let index = shortNsDic.index(forKey: ns) {
                    onlyNs = shortNsDic[index].key
                }
                if let index = shortNsDic.firstIndex(where: {
                    $0 == ns || $1 == ns
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
            .compactMap { $0.getMatchScore(search: sTerm) }
            .filter{$0.score > 0}
            .sorted { $1.score > $0.score }
        
        print(suggestions);
    
        return suggestions
    }
}


let allTagList: [TagItem] = [
    TagItem(namespace: "language", key: "chinese", name: "中文"),
    TagItem(namespace: "language", key: "english", name: "英语"),
    TagItem(namespace: "female", key: "loli", name: "萝莉")
]

func pregReplace(_ text: String, pattern: String, with: String, options: NSRegularExpression.Options = []) -> String {
    let regex = try! NSRegularExpression(pattern: pattern, options: options)
    return regex.stringByReplacingMatches(in: text, options: [],
                                          range: NSMakeRange(0, text.count),
                                          withTemplate: with)
}


struct TagTip : View {
    @State var input = ""
    @State var suggests: [TagSuggestion] = []
    @State var term: String = ""
    
    
    func search(_ value: String) {
        let value = pregReplace(value, pattern: "  +", with: " ")
        input = value
        let regex = try! NSRegularExpression(pattern: "(\\S+:\".+?\"|\".+?\"|\\S+:\\S+|\\S+)")
        let matchs = regex.matches(in: value, options: [], range: NSMakeRange(0, value.count))
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
                                Button("-/+") {
                                    
                                }
                                .buttonStyle(.bordered)
                                Spacer()
                                Button("Finish") {
                                   
                                }
                                .buttonStyle(.bordered)
                            }
                            .padding(.horizontal, 30)
                        }
                    }
                    .onSubmit{
                        print(input)
                    }
                
                Button("搜索"){
                    print(input)
                }.keyboardShortcut(.defaultAction)
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
                        
                    }.onTapGesture {
                        input = String(input[input.startIndex..<input.index(input.endIndex, offsetBy: 0 - term.count)]) + suggestion.tag.searchTerm + " "
                    }
                    Spacer()
                    Text("排除")
                        .onTapGesture {
                            input = String(input[input.startIndex..<input.index(input.endIndex, offsetBy: 0 - term.count)]) + "-" + suggestion.tag.searchTerm + " "
                        }
                }
                
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
                
            }
        }
    }
    
}
