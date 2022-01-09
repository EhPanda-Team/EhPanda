//
//  SearchView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/09.
//

import SwiftUI
import ComposableArchitecture

struct SearchView: View {
    private let store: Store<SearchState, SearchAction>
    @ObservedObject private var viewStore: ViewStore<SearchState, SearchAction>
    private let setting: Setting
    private let tagTranslator: TagTranslator

    init(
        store: Store<SearchState, SearchAction>,
        setting: Setting, tagTranslator: TagTranslator
    ) {
        self.store = store
        viewStore = ViewStore(store)
        self.setting = setting
        self.tagTranslator = tagTranslator
    }

    private var navigationTitle: String {
        viewStore.lastKeyword.isEmpty ? "Search".localized : viewStore.lastKeyword
    }

    var body: some View {
        NavigationView {
            ZStack {
                if viewStore.lastKeyword.isEmpty {
                    ScrollView(showsIndicators: false) {
                        VStack {
                            SuggestionsPanel(
                                historyKeywords: viewStore.historyKeywords.reversed(),
                                historyGalleries: viewStore.historyGalleries,
                                searchKeywordAction: { keyword in
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                        viewStore.send(.fetchGalleries(nil, keyword))
                                    }
                                },
                                removeKeywordAction: { viewStore.send(.removeHistoryKeyword($0)) },
                                reloadHistoryAction: { viewStore.send(.fetchHistoryGalleries) }
                            )
                        }
                    }
                } else {
                    GenericList(
                        galleries: viewStore.galleries,
                        setting: setting,
                        pageNumber: viewStore.pageNumber,
                        loadingState: viewStore.loadingState,
                        footerLoadingState: viewStore.footerLoadingState,
                        fetchAction: { viewStore.send(.fetchGalleries()) },
                        loadMoreAction: { viewStore.send(.fetchMoreGalleries) },
                        translateAction: {
                            tagTranslator.tryTranslate(text: $0, returnOriginal: !setting.translatesTags)
                        }
                    )
                }
            }
            .jumpPageAlert(
                index: viewStore.binding(\.$jumpPageIndex),
                isPresented: viewStore.binding(\.$jumpPageAlertPresented),
                isFocused: viewStore.binding(\.$jumpPageAlertFocused),
                pageNumber: viewStore.pageNumber,
                jumpAction: { viewStore.send(.performJumpPage) }
            )
            .animation(.default, value: viewStore.jumpPageAlertPresented)
            .searchable(text: viewStore.binding(\.$keyword))
            .onSubmit(of: .search) {
                viewStore.send(.fetchGalleries())
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    if viewStore.historyGalleries.isEmpty {
                        viewStore.send(.fetchHistoryGalleries)
                    }
                }
            }
            .onDisappear {
                viewStore.send(.onDisappear)
            }
            .toolbar(content: toolbar)
            .navigationTitle(navigationTitle)
        }
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem(tint: .primary, disabled: viewStore.jumpPageAlertPresented) {
            Button {
                viewStore.send(.cancelSearching)
            } label: {
                Image(systemSymbol: .arrowUturnLeft)
            }
            .disabled(viewStore.lastKeyword.isEmpty)
            ToolbarFeaturesMenu {
                FiltersButton {
                    viewStore.send(.onFiltersButtonTapped)
                }
                JumpPageButton(pageNumber: viewStore.pageNumber) {
                    viewStore.send(.presentJumpPageAlert)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        viewStore.send(.setJumpPageAlertFocused(true))
                    }
                }
            }
        }
    }
}

// MARK: SuggestionsPanel
private struct SuggestionsPanel: View {
    private let historyKeywords: [String]
    private let historyGalleries: [Gallery]
    private let searchKeywordAction: (String) -> Void
    private let removeKeywordAction: (String) -> Void
    private let reloadHistoryAction: () -> Void

    init(
        historyKeywords: [String], historyGalleries: [Gallery],
        searchKeywordAction: @escaping (String) -> Void,
        removeKeywordAction: @escaping (String) -> Void,
        reloadHistoryAction: @escaping () -> Void
    ) {
        self.historyKeywords = historyKeywords
        self.historyGalleries = historyGalleries
        self.searchKeywordAction = searchKeywordAction
        self.removeKeywordAction = removeKeywordAction
        self.reloadHistoryAction = reloadHistoryAction
    }

    var body: some View {
        Group {
            if !historyKeywords.isEmpty {
                HistoryKeywordsSection(
                    keywords: historyKeywords,
                    searchAction: searchKeywordAction,
                    removeAction: removeKeywordAction
                )
            }
            if !historyGalleries.isEmpty {
                HistoryGalleriesSection(galleries: historyGalleries, reloadAction: reloadHistoryAction)
            }
        }
        .padding(.vertical)
    }
}

// MARK: HistoryGalleriesSection
private struct HistoryGalleriesSection: View {
    private let galleries: [Gallery]
    private let reloadAction: () -> Void

    init(galleries: [Gallery], reloadAction: @escaping () -> Void) {
        self.galleries = galleries
        self.reloadAction = reloadAction
    }

    var body: some View {
        SubSection(title: "Recently seen", showAll: false, reloadAction: reloadAction) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack {
                    ForEach(galleries) { gallery in
                        GalleryHistoryCell(gallery: gallery)
                    }
                    .withHorizontalSpacing()
                }
            }
        }
    }
}

// MARK: HistoryKeywordsSection
private struct HistoryKeywordsSection: View {
    private let keywords: [String]
    private let searchAction: (String) -> Void
    private let removeAction: (String) -> Void

    init(keywords: [String], searchAction: @escaping (String) -> Void, removeAction: @escaping (String) -> Void) {
        self.keywords = keywords
        self.searchAction = searchAction
        self.removeAction = removeAction
    }

    var singleKeywords: [String] {
        Array(keywords.prefix(min(keywords.count, 10)))
    }
    var doubleKeywords: ([String], [String]) {
        let isEven = keywords.count % 2 == 0
        let halfCount = keywords.count / 2
        let trailingKeywords = Array(keywords.suffix(halfCount))
        let leadingKeywords = Array(
            keywords.prefix(isEven ? halfCount : halfCount + 1)
        )
        return (leadingKeywords, trailingKeywords)
    }

    var body: some View {
        SubSection(title: "Recently searched", showAll: false) {
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
}

private struct VerticalKeywordsStack: View {
    private let keywords: [String]
    private let searchAction: (String) -> Void
    private let removeAction: (String) -> Void

    init(keywords: [String], searchAction: @escaping (String) -> Void, removeAction: @escaping (String) -> Void) {
        self.keywords = keywords
        self.searchAction = searchAction
        self.removeAction = removeAction
    }

    var body: some View {
        VStack(spacing: 10) {
            ForEach(keywords, id: \.self) { keyword in
                VStack(spacing: 10) {
                    Button {
                        searchAction(keyword)
                    } label: {
                        HistoryKeywordCell(keyword: keyword) {
                            removeAction(keyword)
                        }
                    }
                    .foregroundColor(.primary)
                    Divider().opacity(keyword == keywords.last ? 0 : 1)
                }
            }
        }
    }
}

private struct HistoryKeywordCell: View {
    private let keyword: String
    private let removeAction: () -> Void

    init(keyword: String, removeAction: @escaping () -> Void) {
        self.keyword = keyword
        self.removeAction = removeAction
    }

    var body: some View {
        HStack(spacing: 20) {
            Image(systemSymbol: .magnifyingglass)
            Text(keyword)
            Spacer()
            Image(systemSymbol: .xmark)
                .imageScale(.small)
                .foregroundColor(.secondary)
                .onTapGesture(perform: removeAction)
        }
    }
}

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(
            store: .init(
                initialState: .init(),
                reducer: searchReducer,
                environment: SearchEnvironment(
                    hapticClient: .live,
                    databaseClient: .live
                )
            ),
            setting: .init(),
            tagTranslator: .init()
        )
    }
}
