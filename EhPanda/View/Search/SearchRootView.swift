//
//  SearchRootView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import SwiftUI
import ComposableArchitecture

struct SearchRootView: View {
    private let store: StoreOf<SearchRootReducer>
    @ObservedObject private var viewStore: ViewStoreOf<SearchRootReducer>
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: StoreOf<SearchRootReducer>,
        user: User, setting: Binding<Setting>, blurRadius: Double, tagTranslator: TagTranslator
    ) {
        self.store = store
        viewStore = ViewStore(store)
        self.user = user
        _setting = setting
        self.blurRadius = blurRadius
        self.tagTranslator = tagTranslator
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                SuggestionsPanel(
                    historyKeywords: viewStore.historyKeywords.reversed(),
                    historyGalleries: viewStore.historyGalleries,
                    quickSearchWords: viewStore.quickSearchWords,
                    navigateGalleryAction: { viewStore.send(.setNavigation(.detail($0))) },
                    navigateQuickSearchAction: { viewStore.send(.setNavigation(.quickSearch)) },
                    searchKeywordAction: { keyword in
                        viewStore.send(.setKeyword(keyword))
                        viewStore.send(.setNavigation(.search))
                    },
                    removeKeywordAction: { viewStore.send(.removeHistoryKeyword($0)) }
                )
            }
            .sheet(
                unwrapping: viewStore.binding(\.$route),
                case: /SearchRootReducer.Route.detail,
                isEnabled: DeviceUtil.isPad
            ) { route in
                NavigationView {
                    DetailView(
                        store: store.scope(state: \.detailState, action: SearchRootReducer.Action.detail),
                        gid: route.wrappedValue, user: user, setting: $setting,
                        blurRadius: blurRadius, tagTranslator: tagTranslator
                    )
                }
                .autoBlur(radius: blurRadius).environment(\.inSheet, true).navigationViewStyle(.stack)
            }
            .sheet(unwrapping: viewStore.binding(\.$route), case: /SearchRootReducer.Route.filters) { _ in
                FiltersView(store: store.scope(state: \.filtersState, action: SearchRootReducer.Action.filters))
                    .autoBlur(radius: blurRadius).environment(\.inSheet, true)
            }
            .sheet(unwrapping: viewStore.binding(\.$route), case: /SearchRootReducer.Route.quickSearch) { _ in
                QuickSearchView(
                    store: store.scope(state: \.quickSearchState, action: SearchRootReducer.Action.quickSearch)
                ) { keyword in
                    viewStore.send(.setNavigation(nil))
                    viewStore.send(.setKeyword(keyword))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        viewStore.send(.setNavigation(.search))
                    }
                }
                .accentColor(setting.accentColor)
                .autoBlur(radius: blurRadius)
            }
            .searchable(text: viewStore.binding(\.$keyword))
            .searchSuggestions {
                TagSuggestionView(
                    keyword: viewStore.binding(\.$keyword), translations: tagTranslator.translations,
                    showsImages: setting.showsImagesInTags, isEnabled: setting.showsTagsSearchSuggestion
                )
            }
            .onSubmit(of: .search) {
                viewStore.send(.setNavigation(.search))
            }
            .onAppear {
                viewStore.send(.fetchHistoryGalleries)
                viewStore.send(.fetchDatabaseInfos)
            }
            .background(navigationLinks)
            .toolbar(content: toolbar)
            .navigationTitle(L10n.Localizable.SearchView.Title.search)
        }
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem(tint: .primary) {
            ToolbarFeaturesMenu(symbolRenderingMode: .hierarchical) {
                FiltersButton {
                    viewStore.send(.setNavigation(.filters))
                }
                QuickSearchButton {
                    viewStore.send(.setNavigation(.quickSearch))
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
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /SearchRootReducer.Route.detail) { route in
            DetailView(
                store: store.scope(state: \.detailState, action: SearchRootReducer.Action.detail),
                gid: route.wrappedValue, user: user, setting: $setting,
                blurRadius: blurRadius, tagTranslator: tagTranslator
            )
        }
    }
    var searchViewLink: some View {
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /SearchRootReducer.Route.search) { _ in
            SearchView(
                store: store.scope(state: \.searchState, action: SearchRootReducer.Action.search),
                keyword: viewStore.keyword, user: user, setting: $setting,
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
        quickSearchWords.map { word in
            .init(keyword: word.content, displayText: word.name)
        }
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
                keywords: keywords.map({ WrappedKeyword(keyword: $0) }),
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

    var body: some View {
        HStack(spacing: 20) {
            Button {
                searchAction(wrappedKeyword.keyword)
            } label: {
                Image(systemSymbol: .magnifyingglass)
                Text(wrappedKeyword.displayText ?? wrappedKeyword.keyword).lineLimit(1)
                Spacer()
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
    var displayText: String?
}

struct SearchRootView_Previews: PreviewProvider {
    static var previews: some View {
        SearchRootView(
            store: .init(
                initialState: .init(),
                reducer: SearchRootReducer()
            ),
            user: .init(),
            setting: .constant(.init()),
            blurRadius: 0,
            tagTranslator: .init()
        )
    }
}
