import SwiftUI
import SFSafeSymbols
import Utilities

// MARK: DoubleVerticalKeywordsStack
struct DoubleVerticalKeywordsStack: View {
    private let keywords: [WrappedKeyword]
    private let searchAction: (String) -> Void
    private let removeAction: ((String) -> Void)?

    init(
        keywords: [WrappedKeyword],
        searchAction: @escaping (String) -> Void,
        removeAction: ((String) -> Void)? = nil
    ) {
        self.keywords = keywords
        self.searchAction = searchAction
        self.removeAction = removeAction
    }

    var singleKeywords: [WrappedKeyword] {
        .init(keywords.prefix(min(keywords.count, 10)))
    }
    var doubleKeywords: ([WrappedKeyword], [WrappedKeyword]) {
        var leadingKeywords = [WrappedKeyword]()
        var trailingKeywords = [WrappedKeyword]()
        keywords.enumerated().forEach { (index, keyword) in
            guard index < 20 else { return }
            if index % 2 == 0 {
                leadingKeywords.append(keyword)
            } else {
                trailingKeywords.append(keyword)
            }
        }
        return (leadingKeywords, trailingKeywords)
    }

    var body: some View {
        HStack(alignment: .top, spacing: 30) {
            if !DeviceUtil.isPad {
                VerticalKeywordsStack(
                    keywords: singleKeywords,
                    searchAction: searchAction,
                    removeAction: removeAction
                )
            } else {
                let (leadingKeywords, trailingKeywords) = doubleKeywords
                VerticalKeywordsStack(
                    keywords: leadingKeywords,
                    searchAction: searchAction,
                    removeAction: removeAction
                )
                VerticalKeywordsStack(
                    keywords: trailingKeywords,
                    searchAction: searchAction,
                    removeAction: removeAction
                )
            }
        }
        .padding()
    }
}

struct VerticalKeywordsStack: View {
    private let keywords: [WrappedKeyword]
    private let searchAction: (String) -> Void
    private let removeAction: ((String) -> Void)?

    init(keywords: [WrappedKeyword], searchAction: @escaping (String) -> Void, removeAction: ((String) -> Void)?) {
        self.keywords = keywords
        self.searchAction = searchAction
        self.removeAction = removeAction
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(keywords, id: \.self) { keyword in
                VStack(alignment: .leading, spacing: 10) {
                    KeywordCell(wrappedKeyword: keyword, searchAction: searchAction, removeAction: removeAction)
                    Divider().opacity(keyword == keywords.last ? 0 : 1)
                }
            }
        }
    }
}

struct KeywordCell: View {
    private let wrappedKeyword: WrappedKeyword
    private let searchAction: (String) -> Void
    private let removeAction: ((String) -> Void)?

    init(wrappedKeyword: WrappedKeyword, searchAction: @escaping (String) -> Void, removeAction: ((String) -> Void)?) {
        self.wrappedKeyword = wrappedKeyword
        self.searchAction = searchAction
        self.removeAction = removeAction
    }

    var title: String {
        wrappedKeyword.displayText.isEmpty ? wrappedKeyword.keyword : wrappedKeyword.displayText
    }

    var body: some View {
        HStack(spacing: 20) {
            Button {
                searchAction(wrappedKeyword.keyword)
            } label: {
                Image(systemSymbol: .magnifyingglass)

                Text(title)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .lineLimit(1)
            }
            .tint(.primary)

            if removeAction != nil {
                Button {
                    removeAction?(wrappedKeyword.keyword)
                } label: {
                    Image(systemSymbol: .xmark)
                        .imageScale(.small)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: Definition
struct WrappedKeyword: Hashable {
    let keyword: String
    let displayText: String

    init(keyword: String, displayText: String) {
        self.keyword = keyword
        self.displayText = displayText
    }

    init(keyword: String) {
        self.init(keyword: keyword, displayText: .init())
    }
}
