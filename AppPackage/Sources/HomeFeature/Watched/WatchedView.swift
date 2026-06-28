import SwiftUI
import AppModels
import Resources
import ComposableArchitecture
import SwiftUINavigationExt
import Utilities
import AppComponents
import DateSeekFeature
import GalleryListComponents
import FiltersFeature
import QuickSearchFeature
import DetailFeature

struct WatchedView: View {
    @Bindable private var store: StoreOf<WatchedReducer>
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: StoreOf<WatchedReducer>,
        user: User, setting: Binding<Setting>, blurRadius: Double, tagTranslator: TagTranslator
    ) {
        self.store = store
        self.user = user
        _setting = setting
        self.blurRadius = blurRadius
        self.tagTranslator = tagTranslator
    }

    var body: some View {
        let content =
            ZStack {
                if CookieUtil.didLogin {
                    GenericList(
                        galleries: store.galleries,
                        setting: setting,
                        pageNumber: store.pageNumber,
                        loadingState: store.loadingState,
                        footerLoadingState: store.footerLoadingState,
                        fetchAction: { store.send(.fetchGalleries()) },
                        fetchMoreAction: { store.send(.fetchMoreGalleries) },
                        navigateAction: { store.send(.setNavigation(.detail($0))) },
                        translateAction: {
                            tagTranslator.lookup(word: $0, returnOriginal: !setting.translatesTags)
                        },
                        downloadBadges: store.downloadBadges
                    )
                } else {
                    NotLoginView(action: { store.send(.onNotLoginViewButtonTapped) })
                }
            }
            .sheet(item: $store.route.sending(\.setNavigation).quickSearch) { _ in
                QuickSearchView(
                    store: store.scope(state: \.quickSearchState, action: \.quickSearch)
                ) { keyword in
                    store.send(.setNavigation(nil))
                    store.send(.fetchGalleries(keyword))
                }
                .accentColor(setting.accentColor)
                .autoBlur(radius: blurRadius)
            }
            .sheet(item: $store.route.sending(\.setNavigation).filters) { _ in
                FiltersView(store: store.scope(state: \.filtersState, action: \.filters))
                    .autoBlur(radius: blurRadius).environment(\.inSheet, true)
            }
            .sheet(item: $store.dateSeek.navigation.sending(\.dateSeek.setNavigation), id: \.self) { navigation in
                DateSeekPickerView(
                    selectedDate: $store.dateSeek.date,
                    navigation: navigation.wrappedValue,
                    seekAction: { store.send(.dateSeek(.performSeek($0))) }
                )
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
                store.send(.fetchGalleries())
            }
            .onAppear {
                store.send(.onAppear)
                if store.galleries.isEmpty && CookieUtil.didLogin {
                    DispatchQueue.main.async {
                        store.send(.fetchGalleries())
                    }
                }
            }
            .background(navigationLink)
            .toolbar(content: toolbar)
            .navigationTitle(L10n.Localizable.WatchedView.Title.watched)

        if DeviceUtil.isPad {
            content
                .sheet(item: $store.route.sending(\.setNavigation).detail, id: \.self) { route in
                    NavigationView {
                        DetailView(
                            store: store.scope(state: \.detailState.wrappedValue!, action: \.detail),
                            gid: route.wrappedValue, user: user, setting: $setting,
                            blurRadius: blurRadius, tagTranslator: tagTranslator
                        )
                    }
                    .autoBlur(radius: blurRadius).environment(\.inSheet, true).navigationViewStyle(.stack)
                }
        } else {
            content
        }
    }

    @ViewBuilder private var navigationLink: some View {
        if DeviceUtil.isPhone {
            NavigationLink(unwrapping: $store.route, case: \.detail) { route in
                DetailView(
                    store: store.scope(state: \.detailState.wrappedValue!, action: \.detail),
                    gid: route.wrappedValue, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            }
        }
    }
    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem {
            ToolbarFeaturesMenu {
                DateSeekButton(navigation: store.dateSeekNavigation) { navigation in
                    store.send(.dateSeek(.present(navigation)))
                }
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

struct WatchedView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            WatchedView(
                store: .init(initialState: .init(), reducer: WatchedReducer.init),
                user: .init(),
                setting: .constant(.init()),
                blurRadius: 0,
                tagTranslator: .init()
            )
        }
    }
}
