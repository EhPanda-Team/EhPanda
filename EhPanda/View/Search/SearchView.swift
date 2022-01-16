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
    private let user: User
    private let setting: Setting
    private let tagTranslator: TagTranslator

    init(
        store: Store<SearchState, SearchAction>,
        user: User, setting: Setting, tagTranslator: TagTranslator
    ) {
        self.store = store
        viewStore = ViewStore(store)
        self.user = user
        self.setting = setting
        self.tagTranslator = tagTranslator
    }

    private var searchFieldPlacement: SearchFieldPlacement {
        DeviceUtil.isPad ? .automatic : .navigationBarDrawer(displayMode: .always)
    }

    var body: some View {
        NavigationView {
            ScrollView(showsIndicators: false) {
                SuggestionsPanel(
                    historyKeywords: viewStore.historyKeywords.reversed(),
                    historyGalleries: viewStore.historyGalleries,
                    navigateGalleryAction: { viewStore.send(.setNavigation(.detail($0))) },
                    searchKeywordAction: { keyword in
                        viewStore.send(.setKeyword(keyword))
                        viewStore.send(.setNavigation(.request))
                    },
                    removeKeywordAction: { viewStore.send(.removeHistoryKeyword($0)) }
                )
            }
            .searchable(text: viewStore.binding(\.$keyword), placement: searchFieldPlacement)
            .onSubmit(of: .search) {
                viewStore.send(.setNavigation(.request))
            }
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                    viewStore.send(.fetchHistoryGalleries)
                    viewStore.send(.fetchHistoryKeywords)
                }
            }
            .background(navigationLinks)
            .toolbar(content: toolbar)
            .navigationTitle("Search")
        }
    }

    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem(tint: .primary) {
            FiltersButton(hideText: true) {
                viewStore.send(.onFiltersButtonTapped)
            }
        }
    }
}

private extension SearchView {
    @ViewBuilder var navigationLinks: some View {
        detailViewLink
        searchRequestLink
    }
    var detailViewLink: some View {
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /SearchState.Route.detail) { route in
            DetailView(
                store: store.scope(state: \.detailState, action: SearchAction.detail),
                gid: route.wrappedValue, user: user, setting: setting, tagTranslator: tagTranslator
            )
        }
    }
    var searchRequestLink: some View {
        NavigationLink(unwrapping: viewStore.binding(\.$route), case: /SearchState.Route.request) { _ in
            SearchRequestView(
                store: store.scope(state: \.searchReqeustState, action: SearchAction.searchRequest),
                keyword: viewStore.keyword, user: user, setting: setting, tagTranslator: tagTranslator
            )
        }
    }
}

// MARK: SuggestionsPanel
private struct SuggestionsPanel: View {
    private let historyKeywords: [String]
    private let historyGalleries: [Gallery]
    private let navigateGalleryAction: (String) -> Void
    private let searchKeywordAction: (String) -> Void
    private let removeKeywordAction: (String) -> Void

    init(
        historyKeywords: [String], historyGalleries: [Gallery],
        navigateGalleryAction: @escaping (String) -> Void,
        searchKeywordAction: @escaping (String) -> Void,
        removeKeywordAction: @escaping (String) -> Void
    ) {
        self.historyKeywords = historyKeywords
        self.historyGalleries = historyGalleries
        self.navigateGalleryAction = navigateGalleryAction
        self.searchKeywordAction = searchKeywordAction
        self.removeKeywordAction = removeKeywordAction
    }

    var body: some View {
        ZStack {
            VStack {
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
        .animation(.default, value: historyGalleries)
        .animation(.default, value: historyKeywords)
        .padding(.vertical)
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
            Text(keyword).lineLimit(1)
            Spacer()
            Image(systemSymbol: .xmark)
                .imageScale(.small)
                .foregroundColor(.secondary)
                .onTapGesture(perform: removeAction)
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
        SubSection(title: "Recently seen", showAll: false) {
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

struct SearchView_Previews: PreviewProvider {
    static var previews: some View {
        SearchView(
            store: .init(
                initialState: .init(),
                reducer: searchReducer,
                environment: SearchEnvironment(
                    hapticClient: .live,
                    cookiesClient: .live,
                    databaseClient: .live
                )
            ),
            user: .init(),
            setting: .init(),
            tagTranslator: .init()
        )
    }
}
