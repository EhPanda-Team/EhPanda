import SwiftUI
import AppModels
import Resources
import ComposableArchitecture
import AppTools
import AppComponents
import FiltersFeature
import QuickSearchFeature
import DetailFeature

public struct SearchRootView: View {
    @Bindable private var store: StoreOf<SearchRootReducer>
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    public init(
        store: StoreOf<SearchRootReducer>,
        user: User, setting: Binding<Setting>, blurRadius: Double, tagTranslator: TagTranslator
    ) {
        self.store = store
        self.user = user
        _setting = setting
        self.blurRadius = blurRadius
        self.tagTranslator = tagTranslator
    }

    public var body: some View {
        NavigationStack(path: $store.scope(state: \.path, action: \.path)) {
            let content =
                ScrollView(showsIndicators: false) {
                    SuggestionsPanel(
                        historyKeywords: store.historyKeywords.reversed(),
                        historyGalleries: store.historyGalleries,
                        quickSearchWords: store.quickSearchWords,
                        navigateGalleryAction: { store.send(.galleryTapped($0)) },
                        navigateQuickSearchAction: { store.send(.quickSearchButtonTapped) },
                        searchKeywordAction: { keyword in
                            store.send(.setKeyword(keyword))
                            store.send(.pushSearch)
                        },
                        removeKeywordAction: { store.send(.removeHistoryKeyword($0)) }
                    )
                }
                .sheet(
                    item: $store.scope(state: \.destination?.filters, action: \.destination.filters)
                ) { store in
                    FiltersView(store: store)
                        .autoBlur(radius: blurRadius).environment(\.inSheet, true)
                }
                .sheet(
                    item: $store.scope(state: \.destination?.quickSearch, action: \.destination.quickSearch)
                ) { store in
                    QuickSearchView(store: store) { keyword in
                        self.store.send(.destination(.dismiss))
                        self.store.send(.setKeyword(keyword))
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.store.send(.pushSearch)
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
                    store.send(.pushSearch)
                }
                .onAppear {
                    store.send(.fetchHistoryGalleries)
                }
                .toolbar(content: toolbar)
                .navigationTitle(.RLocalizable.search)

            // Workaround: Prevent the title disappearing issue. The blank subtitle only reserves
            // layout; `verbatim` keeps Xcode from extracting it as a localizable " " key.
            if store.historyKeywords.isEmpty && store.historyGalleries.isEmpty {
                content
                    .navigationSubtitle(Text(verbatim: " "))
            } else {
                content
            }
        } destination: { store in
            switch store.case {
            case .search(let store):
                SearchView(
                    store: store, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            case .gallery(let store):
                galleryDestination(
                    store, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            }
        }
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem(tint: .primary) {
            ToolbarFeaturesMenu(symbolRenderingMode: .hierarchical) {
                FiltersButton {
                    store.send(.filtersButtonTapped)
                }
                QuickSearchButton {
                    store.send(.quickSearchButtonTapped)
                }
            }
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
            .map {
                .init(
                    keyword: $0.effectiveSearchText,
                    displayText: !$0.content.isEmpty ? $0.name : ""
                )
            }
            .removeDuplicates()
    }

    var body: some View {
        SubSection(
            title: .RLocalizable.quickSearch,
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
        SubSection(title: .recentlySearched, showAll: false) {
            DoubleVerticalKeywordsStack(
                keywords: keywords.map(WrappedKeyword.init),
                searchAction: searchAction,
                removeAction: removeAction
            )
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
        SubSection(title: .recentlySeen, showAll: false) {
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
