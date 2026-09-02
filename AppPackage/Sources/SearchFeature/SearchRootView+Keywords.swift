import Dependencies
import DeviceClient
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
import SwiftUI

// MARK: DoubleVerticalKeywordsStack
struct DoubleVerticalKeywordsStack: View {
    @Dependency(\.deviceClient) private var deviceClient
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
    var doubleKeywords: (leading: [WrappedKeyword], trailing: [WrappedKeyword]) {
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
            if deviceClient.deviceType() != .pad {
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
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
        // The delete button stays centred against the whole cell rather than following the
        // keyword's first line: it acts on the row, not on a line of it, and the keyword's
        // flexible frame keeps it pinned to the trailing edge however many lines the keyword takes.
        HStack(spacing: 20) {
            searchButton

            if removeAction != nil {
                Button {
                    removeAction?(wrappedKeyword.keyword)
                } label: {
                    Label(.RLocalizable.delete, systemSymbol: .xmark)
                        .labelStyle(.iconOnly)
                        .imageScale(.small)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    /// Where the magnifier sits against the keyword beside it.
    ///
    /// Above the default size the keyword wraps, and a centred glyph lands beside the *middle* line
    /// of the block, reading as a mark on the wrong row; the first baseline sets it against the
    /// keyword's opening line instead, the way `Label` sets an icon beside a title.
    ///
    /// A gate rather than a constant, because the two alignments disagree on a single line too: an
    /// SF Symbol's baseline sits a shade off the centre of its box, so taking the baseline
    /// everywhere would nudge the glyph at the default size, where the implicit `Button`-label
    /// stack centres it today. D-15 binds default-size appearance, so `.large` and below keep the
    /// centring they already render and only the sizes that can wrap take the baseline.
    private var glyphAlignment: VerticalAlignment {
        dynamicTypeSize <= .large ? .center : .firstTextBaseline
    }

    /// A `Button` centres a multi-line label, so a keyword long enough to wrap at an accessibility
    /// size came out as a column of centred fragments under a leading-aligned list (Phase 16
    /// finding #34). The leading alignment is stated explicitly so it survives however the keyword
    /// breaks; a keyword that fits one line — every keyword at the default size — is unaffected.
    ///
    /// The stack is spelled out rather than left to the implicit label layout for the same reason:
    /// where the magnifier sits against the keyword has to be this view's decision, and
    /// `glyphAlignment` is where that decision lives.
    private var searchButton: some View {
        Button {
            searchAction(wrappedKeyword.keyword)
        } label: {
            HStack(alignment: glyphAlignment) {
                Image(systemSymbol: .magnifyingglass)

                Text(title)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .tint(.primary)
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
