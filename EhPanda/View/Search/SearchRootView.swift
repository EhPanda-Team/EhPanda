//
//  SearchRootView.swift
//  EhPanda
//

import SwiftUI
import ComposableArchitecture

struct SearchRootView: View {
    @Bindable private var store: StoreOf<SearchRootReducer>
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: StoreOf<SearchRootReducer>,
        user: User, setting: Binding<Setting>, blurRadius: Double, tagTranslator: TagTranslator
    ) {
        self.store = store
        self.user = user
        _setting = setting
        self.blurRadius = blurRadius
        self.tagTranslator = tagTranslator
    }

    var body: some View {
        NavigationView {
            let content =
            ScrollView(showsIndicators: false) {
                SuggestionsPanel(
                    historyKeywords: store.historyKeywords.reversed(),
                    historyGalleries: store.historyGalleries,
                    quickSearchWords: store.quickSearchWords,
                    navigateGalleryAction: { store.send(.setNavigation(.detail($0))) },
                    navigateQuickSearchAction: { store.send(.setNavigation(.quickSearch())) },
                    searchKeywordAction: { keyword in
                        store.send(.setKeyword(keyword))
                        store.send(.setNavigation(.search))
                    },
                    removeKeywordAction: { store.send(.removeHistoryKeyword($0)) }
                )
            }
            .sheet(item: $store.route.sending(\.setNavigation).filters) { _ in
                FiltersView(store: store.scope(state: \.filtersState, action: \.filters))
                    .autoBlur(radius: blurRadius).environment(\.inSheet, true)
            }
            .sheet(item: $store.route.sending(\.setNavigation).quickSearch) { _ in
                QuickSearchView(
                    store: store.scope(state: \.quickSearchState, action: \.quickSearch)
                ) { keyword in
                    store.send(.setNavigation(nil))
                    store.send(.setKeyword(keyword))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        store.send(.setNavigation(.search))
                    }
                }
                .accentColor(setting.accentColor)
                .autoBlur(radius: blurRadius)
            }
            .searchable(text: $store.keyword)
            .searchSuggestions {
                TagSuggestionView(
                    keyword: $store.keyword, translations: tagTranslator.translations,
                    showsImages: setting.showsImagesInTags, isEnabled: setting.showsTagsSearchSuggestion
                )
            }
            .onSubmit(of: .search) {
                store.send(.setNavigation(.search))
            }
            .onAppear {
                store.send(.fetchHistoryGalleries)
                store.send(.fetchDatabaseInfos)
            }
            .background(navigationLinks)
            .toolbar(content: toolbar)
            .navigationTitle(L10n.Localizable.SearchView.Title.search)

            if DeviceUtil.isPad {
                content
                    .sheet(item: $store.route.sending(\.setNavigation).detail, id: \.self) { gid in
                        NavigationView {
                            DetailView(
                                store: store.scope(state: \.detailState.wrappedValue!, action: \.detail),
                                gid: gid,
                                user: user,
                                setting: $setting,
                                blurRadius: blurRadius,
                                tagTranslator: tagTranslator
                            )
                        }
                        .autoBlur(radius: blurRadius).environment(\.inSheet, true).navigationViewStyle(.stack)
                    }
            } else {
                // Workaround: Prevent the title disappearing issue.
                if store.historyKeywords.isEmpty && store.historyGalleries.isEmpty {
                    content
                        .navigationSubtitle(Text(" "))
                } else {
                    content
                }
            }
        }
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem(tint: .primary) {
            ToolbarFeaturesMenu(symbolRenderingMode: .hierarchical) {
                FiltersButton {
                    store.send(.setNavigation(.filters()))
                }
                QuickSearchButton {
                    store.send(.setNavigation(.quickSearch()))
                }
            }
        }
    }
}

private extension SearchRootView {
    @ViewBuilder var navigationLinks: some View {
        if DeviceUtil.isPhone {
            detailViewLink
        }
        searchViewLink
    }
    var detailViewLink: some View {
        NavigationLink(unwrapping: $store.route, case: \.detail) { route in
            DetailView(
                store: store.scope(state: \.detailState.wrappedValue!, action: \.detail),
                gid: route.wrappedValue, user: user, setting: $setting,
                blurRadius: blurRadius, tagTranslator: tagTranslator
            )
        }
    }
    var searchViewLink: some View {
        NavigationLink(unwrapping: $store.route, case: \.search) { _ in
            SearchView(
                store: store.scope(state: \.searchState, action: \.search),
                keyword: store.keyword, user: user, setting: $setting,
                blurRadius: blurRadius, tagTranslator: tagTranslator
            )
        }
    }
}

// MARK: SuggestionsPanel
private struct SuggestionsPanel: View {
    private let historyKeywords: [String]
    private let historyGalleries: [Gallery]
    private let quickSearchWords: [QuickSearchWord]
    private let navigateGalleryAction: (String) -> Void
    private let navigateQuickSearchAction: () -> Void
    private let searchKeywordAction: (String) -> Void
    private let removeKeywordAction: (String) -> Void

    init(
        historyKeywords: [String], historyGalleries: [Gallery],
        quickSearchWords: [QuickSearchWord],
        navigateGalleryAction: @escaping (String) -> Void,
        navigateQuickSearchAction: @escaping () -> Void,
        searchKeywordAction: @escaping (String) -> Void,
        removeKeywordAction: @escaping (String) -> Void
    ) {
        self.historyKeywords = historyKeywords
        self.historyGalleries = historyGalleries
        self.quickSearchWords = quickSearchWords
        self.navigateGalleryAction = navigateGalleryAction
        self.navigateQuickSearchAction = navigateQuickSearchAction
        self.searchKeywordAction = searchKeywordAction
        self.removeKeywordAction = removeKeywordAction
    }

    var body: some View {
        ZStack {
            VStack {
                if !quickSearchWords.isEmpty {
                    QuickSearchWordsSection(
                        quickSearchWords: quickSearchWords,
                        showAllAction: navigateQuickSearchAction,
                        searchAction: searchKeywordAction
                    )
                }
                if !historyKeywords.isEmpty {
                    HistoryKeywordsSection(
                        keywords: historyKeywords,
                        searchAction: searchKeywordAction,
                        removeAction: removeKeywordAction
                    )
                }
                if !historyGalleries.isEmpty {
                    HistoryGalleriesSection(
                        galleries: historyGalleries,
                        navigationAction: navigateGalleryAction
                    )
                }
            }
        }
        .animation(.default, value: quickSearchWords)
        .animation(.default, value: historyGalleries)
        .animation(.default, value: historyKeywords)
        .padding(.vertical)
    }
}

// MARK: QuickSearchWordsSection
private struct QuickSearchWordsSection: View {
    private let quickSearchWords: [QuickSearchWord]
    private let showAllAction: () -> Void
    private let searchAction: (String) -> Void

    init(
        quickSearchWords: [QuickSearchWord],
        showAllAction: @escaping () -> Void,
        searchAction: @escaping (String) -> Void
    ) {
        self.quickSearchWords = quickSearchWords
        self.showAllAction = showAllAction
        self.searchAction = searchAction
    }

    private var keywords: [WrappedKeyword] {
        quickSearchWords
            .map({ .init(keyword: $0.content, displayText: $0.name) })
            .removeDuplicates()
    }

    var body: some View {
        SubSection(
            title: L10n.Localizable.SearchView.Section.Title.quickSearch,
            showAll: true, tint: .primary, showAllAction: showAllAction
        ) {
            DoubleVerticalKeywordsStack(keywords: keywords, searchAction: searchAction)
        }
    }
}

// MARK: HistoryKeywordsSection
private struct HistoryKeywordsSection: View {
    private let keywords: [String]
    private let searchAction: (String) -> Void
    private let removeAction: ((String) -> Void)

    init(keywords: [String], searchAction: @escaping (String) -> Void, removeAction: @escaping (String) -> Void) {
        self.keywords = keywords
        self.searchAction = searchAction
        self.removeAction = removeAction
    }

    var body: some View {
        SubSection(title: L10n.Localizable.SearchView.Section.Title.recentlySearched, showAll: false) {
            DoubleVerticalKeywordsStack(
                keywords: keywords.map(WrappedKeyword.init),
                searchAction: searchAction,
                removeAction: removeAction
            )
        }
    }
}

private struct DoubleVerticalKeywordsStack: View {
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

private struct VerticalKeywordsStack: View {
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

private struct KeywordCell: View {
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

// MARK: HistoryGalleriesSection
private struct HistoryGalleriesSection: View {
    private let galleries: [Gallery]
    private let navigationAction: (String) -> Void

    init(galleries: [Gallery], navigationAction: @escaping (String) -> Void) {
        self.galleries = galleries
        self.navigationAction = navigationAction
    }

    var body: some View {
        SubSection(title: L10n.Localizable.SearchView.Section.Title.recentlySeen, showAll: false) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(galleries) { gallery in
                        Button {
                            navigationAction(gallery.id)
                        } label: {
                            GalleryHistoryCell(gallery: gallery)
                                .tint(.primary).multilineTextAlignment(.leading)
                        }
                    }
                    .withHorizontalSpacing()
                }
            }
        }
    }
}

// MARK: Definition
private struct WrappedKeyword: Hashable {
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

struct SearchRootView_Previews: PreviewProvider {
    static var previews: some View {
        SearchRootView(
            store: .init(initialState: .init(), reducer: SearchRootReducer.init),
            user: .init(),
            setting: .constant(.init()),
            blurRadius: 0,
            tagTranslator: .init()
        )
    }
}
