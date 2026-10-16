import AppComponents
import AppModels
import AppTools
public import ComposableArchitecture
import CookieClient
import DateSeekFeature
import DetailFeature
import GalleryListComponents
import QuickSearchFeature
import ReadingFeature
import Resources
import SFSafeSymbols
import SFSafeSymbolsExt
public import SwiftUI
import SystemNotification
import TagTranslationFeature

public struct FavoritesView: View {
    @SharedReader(.didLogin) private var didLogin: Bool
    @Bindable private var store: StoreOf<FavoritesReducer>

    public init(store: StoreOf<FavoritesReducer>) {
        self.store = store
    }

    private var navigationTitle: String {
        let favoriteCategory = store.user.getFavoriteCategory(index: store.favoritesIndex)
        return (store.favoritesIndex == -1 ? String(localized: .RLocalizable.favorites) : favoriteCategory)
    }

    public var body: some View {
        GalleryNavigationContainer(
            store: store,
            state: \.path,
            action: \.path
        ) {
            content
            .animation(.default, value: didLogin)
            .sheet(
                item: $store.scope(\.$destination, action: \.destination).quickSearch
            ) { store in
                QuickSearchView(store: store) { keyword in
                    self.store.send(.destination(.dismiss))
                    self.store.send(.fetchGalleries(keyword: keyword))
                }
                .privacyMask()
            }
            .sheet(
                item: $store.scope(\.$destination, action: \.destination).dateSeek
            ) { store in
                @Bindable var store = store
                DateSeekPickerView(
                    selectedDate: $store.date,
                    navigation: store.navigation,
                    seekAction: { store.send(.performSeek($0)) }
                )
                .privacyMask()
            }
            .fullScreenCover(item: $store.scope(\.$destination, action: \.destination).reading) { store in
                ReadingView(store: store)
                    .privacyMask()
            }
            .toast($store.scope(\.$toast, action: \.toast))
            .searchable(text: $store.keyword, placement: .navigationBarDrawer)
            .searchSuggestions {
                TagSuggestionView(
                    keyword: $store.keyword, translations: store.tagTranslator.translations,
                    showsImages: store.setting.showImagesInTags, isEnabled: store.setting.showTagsSearchSuggestion
                )
            }
            .onSubmit(of: .search) {
                store.send(.fetchGalleries())
            }
            .toolbar(content: toolbar)
            .navigationTitle(navigationTitle)
            .toolbarTitleDisplayMode(.inlineLarge)
        }
    }

    @ContentBuilder private var content: some View {
        if didLogin {
            GalleryList(
                displayMode: store.setting.galleryListPresentation[.favorites],
                showsGridRating: false,
                galleries: store.galleries ?? [],
                pageNumber: store.pageNumber,
                loadingState: store.readingRequestID == nil ? store.loadingState ?? .idle : .loading,
                footerLoadingState: store.footerLoadingState ?? .idle,
                fetchAction: { store.send(.fetchGalleries()) },
                fetchMoreAction: { store.send(.fetchMoreGalleries) },
                navigateAction: { store.send(.galleryTapped($0)) },
                readAction: { store.send(.openReading($0)) },
                translateAction: {
                    store.tagTranslator.lookup(word: $0, returnOriginal: !store.setting.translateTags)
                },
                downloadBadges: store.downloadBadges,
                scrollPositionID: $store.visibleGalleryID
            )
            .accessibilityIdentifier("favorites-gallery-list")
            .transition(.opacity)
        } else {
            NotLoginView(action: { store.send(.onNotLoginViewButtonTapped) })
                .transition(.opacity)
                .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }

    @ContentBuilder private func toolbar() -> some ToolbarContent {
        ToolbarItem(placement: .topBarTrailing) {
            GalleryLayoutPicker(scope: .favorites)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu {
                Picker(selection: $store.sortOrder.sending(\.selectSortOrder)) {
                    ForEach(FavoritesSortOrder.allCases) { order in
                        Text(order.value).tag(Optional(order))
                    }
                } label: {
                    Text(.sortOrder)
                }
                .pickerStyle(.inline)
            } label: {
                Label(.sortOrder, systemSymbol: .arrowUpArrowDownCircle)
                    .symbolRenderingMode(.hierarchical)
            }
        }
        ToolbarOverflowMenu {
            DateSeekButton(navigation: store.dateSeekNavigation) { navigation in
                store.send(.dateSeekButtonTapped(navigation))
            }
            QuickSearchButton {
                store.send(.quickSearchButtonTapped)
            }
        }
    }
}

#Preview("Initial") {
    withDependencies {
        $0.cookieClient = .previewLoggedIn
    } operation: {
        FavoritesView(
            store: .init(
                initialState: {
                    var state = FavoritesReducer.State()
                    state.rawGalleries[state.favoritesIndex] = Gallery.previews(count: 10)
                    return state
                }(),
                reducer: FavoritesReducer.init
            )
        )
    }
}
