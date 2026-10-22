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
                    hasGalleryHistory: !store.galleryHistory.isEmpty,
                    quickSearchWords: store.quickSearchWords,
                    containerHeight: containerHeight,
                    navigateGalleryAction: { store.send(.galleryTapped($0)) },
                    navigateQuickSearchAction: { store.send(.quickSearchButtonTapped) },
                    searchKeywordAction: { keyword in
                        store.send(.setKeyword(keyword))
                        store.send(.pushSearch)
                    },
                    removeKeywordAction: { store.send(.removeHistoryKeyword($0)) },
                    removeAllKeywordsAction: { store.send(.removeAllHistoryKeywords) },
                    removeAllGalleriesAction: { store.send(.removeAllHistoryGalleries) }
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
    private let hasGalleryHistory: Bool
    private let quickSearchWords: [QuickSearchWord]
    private let containerHeight: CGFloat
    private let navigateGalleryAction: (Gallery) -> Void
    private let navigateQuickSearchAction: () -> Void
    private let searchKeywordAction: (String) -> Void
    private let removeKeywordAction: (String) -> Void
    private let removeAllKeywordsAction: () -> Void
    private let removeAllGalleriesAction: () -> Void

    init(
        historyKeywords: [String], historyGalleries: [Gallery], hasGalleryHistory: Bool,
        quickSearchWords: [QuickSearchWord], containerHeight: CGFloat,
        navigateGalleryAction: @escaping (Gallery) -> Void,
        navigateQuickSearchAction: @escaping () -> Void,
        searchKeywordAction: @escaping (String) -> Void,
        removeKeywordAction: @escaping (String) -> Void,
        removeAllKeywordsAction: @escaping () -> Void,
        removeAllGalleriesAction: @escaping () -> Void
    ) {
        self.historyKeywords = historyKeywords
        self.historyGalleries = historyGalleries
        self.hasGalleryHistory = hasGalleryHistory
        self.quickSearchWords = quickSearchWords
        self.containerHeight = containerHeight
        self.navigateGalleryAction = navigateGalleryAction
        self.navigateQuickSearchAction = navigateQuickSearchAction
        self.searchKeywordAction = searchKeywordAction
        self.removeKeywordAction = removeKeywordAction
        self.removeAllKeywordsAction = removeAllKeywordsAction
        self.removeAllGalleriesAction = removeAllGalleriesAction
    }

    /// Each section inserts or removes whole rows as words, keywords and galleries come and go —
    /// position motion, so the diffs land instantly under Reduce Motion (D-29).
    private var listAnimation: Animation? {
        reduceMotion ? nil : .default
    }

    var body: some View {
        let sections = Group {
            HistoryKeywordsSection(
                keywords: historyKeywords,
                searchAction: searchKeywordAction,
                removeAction: removeKeywordAction,
                removeAllAction: removeAllKeywordsAction
            )
            HistoryGalleriesSection(
                galleries: historyGalleries, hasHistory: hasGalleryHistory,
                navigationAction: navigateGalleryAction,
                removeAllAction: removeAllGalleriesAction
            )
            QuickSearchWordsSection(
                quickSearchWords: quickSearchWords,
                showAllAction: navigateQuickSearchAction,
                searchAction: searchKeywordAction
            )
        }
        VStack(spacing: 32) {
            ForEach(sections: sections) { section in
                SearchSuggestionSection(section: section)
            }
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
        Section {
            if quickSearchWords.isEmpty {
                Text(.quickSearchEmpty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                    .padding(.horizontal)
            } else {
                DoubleVerticalKeywordsStack(keywords: keywords, searchAction: searchAction)
            }
        } header: {
            Text(.RLocalizable.quickSearch)
        }
        .sectionActions {
            Button(.showAll, action: showAllAction)
        }
    }
}

// MARK: HistoryKeywordsSection
private struct HistoryKeywordsSection: View {
    private let keywords: [String]
    private let searchAction: (String) -> Void
    private let removeAction: (String) -> Void
    private let removeAllAction: () -> Void

    init(
        keywords: [String], searchAction: @escaping (String) -> Void,
        removeAction: @escaping (String) -> Void, removeAllAction: @escaping () -> Void
    ) {
        self.keywords = keywords
        self.searchAction = searchAction
        self.removeAction = removeAction
        self.removeAllAction = removeAllAction
    }

    var body: some View {
        Section {
            if keywords.isEmpty {
                Text(.recentlySearchedEmpty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
                    .padding(.horizontal)
            } else {
                DoubleVerticalKeywordsStack(
                    keywords: keywords.map(WrappedKeyword.init),
                    searchAction: searchAction,
                    removeAction: removeAction
                )
            }
        } header: {
            Text(.recentlySearched)
        }
        .sectionActions {
            RemoveSearchHistoryButton(
                message: .removeSearchesConfirmation, isEmpty: keywords.isEmpty,
                identifier: "search-remove-all-keywords", action: removeAllAction
            )
        }
    }
}

// MARK: HistoryGalleriesSection
private struct HistoryGalleriesSection: View {
    private let galleries: [Gallery]
    private let hasHistory: Bool
    private let navigationAction: (Gallery) -> Void
    private let removeAllAction: () -> Void

    init(
        galleries: [Gallery], hasHistory: Bool, navigationAction: @escaping (Gallery) -> Void,
        removeAllAction: @escaping () -> Void
    ) {
        self.galleries = galleries
        self.hasHistory = hasHistory
        self.navigationAction = navigationAction
        self.removeAllAction = removeAllAction
    }

    var body: some View {
        Section {
            if galleries.isEmpty {
                Text(.recentlySeenEmpty)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 96, alignment: .topLeading)
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
        } header: {
            Text(.recentlySeen)
        }
        .sectionActions {
            RemoveSearchHistoryButton(
                message: .removeSeenConfirmation, isEmpty: !hasHistory,
                identifier: "search-remove-all-galleries", action: removeAllAction
            )
        }
    }
}

private struct SearchSuggestionSection: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    let section: SectionConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            let headingLayout = dynamicTypeSize.isAccessibilitySize
                ? AnyLayout(VStackLayout(alignment: .leading, spacing: 8))
                : AnyLayout(HStackLayout())
            headingLayout {
                HStack {
                    section.header
                }
                .font(.title3.bold())
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .accessibilityAddTraits(.isHeader)

                section.actions
                    .font(.subheadline)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal)

            section.content
        }
    }
}

private struct RemoveSearchHistoryButton: View {
    @State private var isConfirming = false
    let message: LocalizedStringResource
    let isEmpty: Bool
    let identifier: String
    let action: () -> Void

    var body: some View {
        Button(.removeAll) {
            isConfirming = true
        }
        .disabled(isEmpty)
        .accessibilityIdentifier(identifier)
        .confirmationDialog(message, isPresented: $isConfirming, titleVisibility: .visible) {
            Button(.removeAll, role: .destructive, action: action)
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
