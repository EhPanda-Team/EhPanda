//
//  SuggestionProvider.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/11/23.
//

import SwiftUI

struct SuggestionProvider: View {
    @Binding private var keyword: String

    init(keyword: Binding<String>) {
        _keyword = keyword
    }

    private var keywords: [String] {
        []
//        store.appState.homeInfo.historyKeywords.reversed().filter({ word in
//            keyword.isEmpty ? true : word.contains(keyword)
//        })
    }

    var body: some View {
        ForEach(keywords, id: \.self) { word in
            HStack {
                Text(word).foregroundStyle(.tint)
                Spacer()
                Image(systemName: "xmark").imageScale(.small)
                    .foregroundColor(.secondary).onTapGesture {
//                        store.dispatch(.removeHistoryKeyword(text: word))
                    }
            }
            .contentShape(Rectangle())
            .onTapGesture { keyword = word }
        }
    }
}
