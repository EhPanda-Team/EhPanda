//
//  ToplistsView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/08.
//

import SwiftUI
import ComposableArchitecture

struct ToplistsView: View {
    private let store: StoreOf<ToplistsReducer>
    @ObservedObject private var viewStore: ViewStoreOf<ToplistsReducer>
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: StoreOf<ToplistsReducer>,
        user: User, setting: Binding<Setting>, blurRadius: Double, tagTranslator: TagTranslator
    ) {
        self.store = store
        viewStore = ViewStore(store)
        self.user = user
        _setting = setting
        self.blurRadius = blurRadius
        self.tagTranslator = tagTranslator
    }

    private var navigationTitle: String {
        [L10n.Localizable.ToplistsView.Title.toplists, viewStore.type.value].joined(separator: " - ")
    }

    var body: some View {
        GenericList(
            galleries: viewStore.filteredGalleries ?? [],
            setting: setting,
            pageNumber: viewStore.pageNumber,
            loadingState: viewStore.loadingState ?? .idle,
            footerLoadingState: viewStore.footerLoadingState ?? .idle,
            fetchAction: { viewStore.send(.fetchGalleries()) },
            fetchMoreAction: { viewStore.send(.fetchMoreGalleries) },
            navigateAction: { viewStore.send(.setNavigation(.detail($0))) },
            translateAction: {
                tagTranslator.lookup(word: $0, returnOriginal: !setting.translatesTags)
            }
        )
        .sheet(
            unwrapping: viewStore.binding(\.$route),
            case: /ToplistsReducer.Route.detail,
            isEnabled: DeviceUtil.isPad
        ) { route in
            NavigationView {
                DetailView(
                    store: store.scope(state: \.detailState, action: ToplistsReducer.Action.detail),
                    gid: route.wrappedValue, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            }
            .autoBlur(radius: blurRadius).environment(\.inSheet, true).navigationViewStyle(.stack)
        }
        .jumpPageAlert(
            index: viewStore.binding(\.$jumpPageIndex),
            isPresented: viewStore.binding(\.$jumpPageAlertPresented),
            isFocused: viewStore.binding(\.$jumpPageAlertFocused),
            pageNumber: viewStore.pageNumber ?? .init(),
            jumpAction: { viewStore.send(.performJumpPage) }
        )
        .searchable(text: viewStore.binding(\.$keyword), prompt: L10n.Localizable.Searchable.Prompt.filter)
        .navigationBarBackButtonHidden(viewStore.jumpPageAlertPresented)
        .animation(.default, value: viewStore.jumpPageAlertPresented)
        .onAppear {
            if viewStore.galleries?.isEmpty != false {
                DispatchQueue.main.async {
                    viewStore.send(.fetchGalleries())
                }
            }
        }
        .background(navigationLink)
        .toolbar(content: toolbar)
        .navigationTitle(navigationTitle)
    }

    @ViewBuilder private var navigationLink: some View {
        if DeviceUtil.isPhone {
            NavigationLink(unwrapping: viewStore.binding(\.$route), case: /ToplistsReducer.Route.detail) { route in
                DetailView(
                    store: store.scope(state: \.detailState, action: ToplistsReducer.Action.detail),
                    gid: route.wrappedValue, user: user, setting: $setting,
                    blurRadius: blurRadius, tagTranslator: tagTranslator
                )
            }
        }
    }
    private func toolbar() -> some ToolbarContent {
        CustomToolbarItem(disabled: viewStore.jumpPageAlertPresented) {
            ToplistsTypeMenu(type: viewStore.type) { type in
                if type != viewStore.type {
                    viewStore.send(.setToplistsType(type))
                }
            }
            if AppUtil.galleryHost == .ehentai {
                JumpPageButton(pageNumber: viewStore.pageNumber ?? .init(), hideText: true) {
                    viewStore.send(.presentJumpPageAlert)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        viewStore.send(.setJumpPageAlertFocused(true))
                    }
                }
            }
        }
    }
}

// MARK: Definition
enum ToplistsType: Int, Codable, CaseIterable, Identifiable {
    var id: Int { rawValue }

    case yesterday
    case pastMonth
    case pastYear
    case allTime
}

extension ToplistsType {
    var value: String {
        switch self {
        case .yesterday:
            return L10n.Localizable.Enum.ToplistsType.Value.yesterday
        case .pastMonth:
            return L10n.Localizable.Enum.ToplistsType.Value.pastMonth
        case .pastYear:
            return L10n.Localizable.Enum.ToplistsType.Value.pastYear
        case .allTime:
            return L10n.Localizable.Enum.ToplistsType.Value.allTime
        }
    }
    var categoryIndex: Int {
        switch self {
        case .yesterday:
            return 15
        case .pastMonth:
            return 13
        case .pastYear:
            return 12
        case .allTime:
            return 11
        }
    }
}

struct ToplistsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            ToplistsView(
                store: .init(
                    initialState: .init(),
                    reducer: ToplistsReducer()
                ),
                user: .init(),
                setting: .constant(.init()),
                blurRadius: 0,
                tagTranslator: .init()
            )
        }
    }
}
