import AppComponents
import AppModels
import AppTools
public import ComposableArchitecture
import DetailFeature
import FiltersFeature
import QuickSearchFeature
import Resources
public import SwiftUI

public struct SearchRootView: View {
    @Bindable private var store: StoreOf<SearchRootReducer>
    @State private var containerHeight: CGFloat = 0

    public init(store: StoreOf<SearchRootReducer>) {
        self.store = store
    }

    public var body: some View {
        NavigationStack(path: $store.scope(\.path, action: \.path)) {
            ScrollView {
                SuggestionsPanel(
                    historyKeywords: store.historyKeywords.reversed(),
                    historyGalleries: store.historyGalleries,
                    quickSearchWords: store.quickSearchWords,
                    containerHeight: containerHeight,
                    navigateGalleryAction: { store.send(.galleryTapped($0)) },
                    navigateQuickSearchAction: { store.send(.quickSearchButtonTapped) },
                    searchKeywordAction: { keyword in
                        store.send(.setKeyword(keyword))
                        store.send(.pushSearch)
                    },
                    removeKeywordAction: { store.send(.removeHistoryKeyword($0)) }
                )
            }
            .scrollIndicators(.hidden)
            .scrollEdgeEffectStyle(.soft, for: .top)
            .onGeometryChange(for: CGFloat.self, of: \.size.height) {
                containerHeight = $0
            }
            .sheet(
                item: $store.scope(\.$destination, action: \.destination).filters
            ) { store in
                FiltersView(store: store)
                    .privacyMask()
            }
            .sheet(
                item: $store.scope(\.$destination, action: \.destination).quickSearch
            ) { store in
                QuickSearchView(store: store) { keyword in
                    self.store.send(.destination(.dismiss))
                    self.store.send(.setKeyword(keyword))
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        self.store.send(.pushSearch)
                    }
                }
                .privacyMask()
            }
            .searchable(text: $store.keyword, placement: .navigationBarDrawer(displayMode: .always))
            .searchSuggestions {
                TagSuggestionView(
                    keyword: $store.keyword, translations: store.tagTranslator.translations,
                    showsImages: store.setting.showImagesInTags, isEnabled: store.setting.showTagsSearchSuggestion
                )
            }
            .onSubmit(of: .search) {
                store.send(.pushSearch)
            }
            .toolbar(content: toolbar)
            .toolbarTitleDisplayMode(.inlineLarge)
            .navigationTitle(.RLocalizable.search)
        } destination: { store in
            switch store.case {
            case .search(let store):
                SearchView(store: store)
            case .gallery(let store):
                galleryDestination(store)
            }
        }
    }

    @ContentBuilder private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            QuickSearchButton {
                store.send(.quickSearchButtonTapped)
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            FiltersButton {
                store.send(.filtersButtonTapped)
            }
        }
    }
}

// MARK: SuggestionsPanel
private struct SuggestionsPanel: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let historyKeywords: [String]
    private let historyGalleries: [Gallery]
    private let quickSearchWords: [QuickSearchWord]
    private let containerHeight: CGFloat
    private let navigateGalleryAction: (Gallery) -> Void
    private let navigateQuickSearchAction: () -> Void
    private let searchKeywordAction: (String) -> Void
    private let removeKeywordAction: (String) -> Void

    init(
        historyKeywords: [String], historyGalleries: [Gallery],
        quickSearchWords: [QuickSearchWord], containerHeight: CGFloat,
        navigateGalleryAction: @escaping (Gallery) -> Void,
        navigateQuickSearchAction: @escaping () -> Void,
        searchKeywordAction: @escaping (String) -> Void,
        removeKeywordAction: @escaping (String) -> Void
    ) {
        self.historyKeywords = historyKeywords
        self.historyGalleries = historyGalleries
        self.quickSearchWords = quickSearchWords
        self.containerHeight = containerHeight
        self.navigateGalleryAction = navigateGalleryAction
        self.navigateQuickSearchAction = navigateQuickSearchAction
        self.searchKeywordAction = searchKeywordAction
        self.removeKeywordAction = removeKeywordAction
    }

    /// Each section inserts or removes whole rows as words, keywords and galleries come and go —
    /// position motion, so the diffs land instantly under Reduce Motion (D-29).
    private var listAnimation: Animation? {
        reduceMotion ? nil : .default
    }

    var body: some View {
        VStack {
            HistoryKeywordsSection(
                keywords: historyKeywords,
                searchAction: searchKeywordAction,
                removeAction: removeKeywordAction
            )
            HistoryGalleriesSection(
                galleries: historyGalleries,
                navigationAction: navigateGalleryAction
            )
            QuickSearchWordsSection(
                quickSearchWords: quickSearchWords,
                showAllAction: navigateQuickSearchAction,
                searchAction: searchKeywordAction
            )
        }
        // Keep rows at their intrinsic height before applying the sparse-content viewport floor.
        .fixedSize(horizontal: false, vertical: true)
        // Keep the panel at least as tall as its scroll viewport when content is sparse.
        .frame(maxWidth: .infinity, minHeight: containerHeight, alignment: .top)
        .animation(listAnimation, value: quickSearchWords)
        .animation(listAnimation, value: historyGalleries)
        .animation(listAnimation, value: historyKeywords)
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
            showAll: true, showAllAction: showAllAction
        ) {
            if quickSearchWords.isEmpty {
                Text(.quickSearchEmpty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                    .padding(.horizontal)
            } else {
                DoubleVerticalKeywordsStack(keywords: keywords, searchAction: searchAction)
            }
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
            if keywords.isEmpty {
                Text(.recentlySearchedEmpty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                    .padding(.horizontal)
            } else {
                DoubleVerticalKeywordsStack(
                    keywords: keywords.map(WrappedKeyword.init),
                    searchAction: searchAction,
                    removeAction: removeAction
                )
            }
        }
    }
}

// MARK: HistoryGalleriesSection
private struct HistoryGalleriesSection: View {
    private let galleries: [Gallery]
    private let navigationAction: (Gallery) -> Void

    init(galleries: [Gallery], navigationAction: @escaping (Gallery) -> Void) {
        self.galleries = galleries
        self.navigationAction = navigationAction
    }

    var body: some View {
        SubSection(title: .recentlySeen, showAll: false) {
            if galleries.isEmpty {
                Text(.recentlySeenEmpty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
                    .padding(.horizontal)
            } else {
                ScrollView(.horizontal) {
                    HStack {
                        ForEach(galleries) { gallery in
                            Button {
                                navigationAction(gallery)
                            } label: {
                                GalleryHistoryCell(gallery: gallery)
                                    .tint(.primary).multilineTextAlignment(.leading)
                            }
                            .frame(maxHeight: .infinity, alignment: .top)
                        }
                        .withHorizontalSpacing()
                    }
                    .fixedSize(horizontal: false, vertical: true)
                }
                .scrollIndicators(.hidden)
            }
        }
    }
}

#Preview("Initial") {
    SearchRootView(
        store: .init(
            initialState: {
                var state = SearchRootReducer.State()
                state.historyGalleries = Gallery.previews(count: 5)
                return state
            }(),
            reducer: SearchRootReducer.init
        )
    )
}
