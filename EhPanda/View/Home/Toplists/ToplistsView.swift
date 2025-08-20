//
//  ToplistsView.swift
//  EhPanda
//

import SwiftUI
import ComposableArchitecture

struct ToplistsView: View {
    @Bindable private var store: StoreOf<ToplistsReducer>
    private let user: User
    @Binding private var setting: Setting
    private let blurRadius: Double
    private let tagTranslator: TagTranslator

    init(
        store: StoreOf<ToplistsReducer>,
        user: User, setting: Binding<Setting>, blurRadius: Double, tagTranslator: TagTranslator
    ) {
        self.store = store
        self.user = user
        _setting = setting
        self.blurRadius = blurRadius
        self.tagTranslator = tagTranslator
    }

    private var navigationTitle: String {
        [L10n.Localizable.ToplistsView.Title.toplists, store.type.value].joined(separator: " - ")
    }

    var body: some View {
        let content =
        GenericList(
            galleries: store.filteredGalleries ?? [],
            setting: setting,
            pageNumber: store.pageNumber,
            loadingState: store.loadingState ?? .idle,
            footerLoadingState: store.footerLoadingState ?? .idle,
            fetchAction: { store.send(.fetchGalleries()) },
            fetchMoreAction: { store.send(.fetchMoreGalleries) },
            navigateAction: { store.send(.setNavigation(.detail($0))) },
            translateAction: {
                tagTranslator.lookup(word: $0, returnOriginal: !setting.translatesTags)
            }
        )
        .jumpPageAlert(
            index: $store.jumpPageIndex,
            isPresented: $store.jumpPageAlertPresented,
            isFocused: $store.jumpPageAlertFocused,
            pageNumber: store.pageNumber ?? .init(),
            jumpAction: { store.send(.performJumpPage) }
        )
        .searchable(text: $store.keyword, prompt: L10n.Localizable.Searchable.Prompt.filter)
        .navigationBarBackButtonHidden(store.jumpPageAlertPresented)
        .animation(.default, value: store.jumpPageAlertPresented)
        .onAppear {
            if store.galleries?.isEmpty != false {
                DispatchQueue.main.async {
                    store.send(.fetchGalleries())
                }
            }
        }
        .background(navigationLink)
        .toolbar(content: toolbar)
        .navigationTitle(navigationTitle)

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
        CustomToolbarItem(disabled: store.jumpPageAlertPresented) {
            ToplistsTypeMenu(type: store.type) { type in
                if type != store.type {
                    store.send(.setToplistsType(type))
                }
            }
            if AppUtil.galleryHost == .ehentai {
                JumpPageButton(pageNumber: store.pageNumber ?? .init(), hideText: true) {
                    store.send(.presentJumpPageAlert)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        store.send(.setJumpPageAlertFocused(true))
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
                store: .init(initialState: .init(), reducer: ToplistsReducer.init),
                user: .init(),
                setting: .constant(.init()),
                blurRadius: 0,
                tagTranslator: .init()
            )
        }
    }
}
