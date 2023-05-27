//
//  PreviewsView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 4/01/10.
//

import SwiftUI
import Kingfisher
import ComposableArchitecture

struct PreviewsView: View {
    private let store: StoreOf<PreviewsReducer>
    @ObservedObject private var viewStore: ViewStoreOf<PreviewsReducer>
    private let gid: String
    @Binding private var setting: Setting
    private let blurRadius: Double

    init(
        store: StoreOf<PreviewsReducer>,
        gid: String, setting: Binding<Setting>, blurRadius: Double
    ) {
        self.store = store
        viewStore = ViewStore(store)
        self.gid = gid
        _setting = setting
        self.blurRadius = blurRadius
    }

    private var gridItems: [GridItem] {
        [GridItem(
            .adaptive(
                minimum: Defaults.ImageSize.previewMinW,
                maximum: Defaults.ImageSize.previewMaxW
            ),
            spacing: 10
        )]
    }

    var body: some View {
        ScrollView {
            LazyVGrid(columns: gridItems) {
                ForEach(1..<viewStore.gallery.pageCount + 1, id: \.self) { index in
                    VStack {
                        let (url, modifier) = PreviewResolver.getPreviewConfigs(
                            originalURL: viewStore.previewURLs[index]
                        )
                        Button {
                            viewStore.send(.updateReadingProgress(index))
                            viewStore.send(.setNavigation(.reading))
                        } label: {
                            KFImage.url(url, cacheKey: viewStore.previewURLs[index]?.absoluteString)
                                .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.previewAspect)) }
                                .imageModifier(modifier).fade(duration: 0.25).resizable().scaledToFit()
                        }
                        Text("\(index)").font(DeviceUtil.isPadWidth ? .callout : .caption).foregroundColor(.secondary)
                    }
                    .onAppear {
                        if viewStore.databaseLoadingState != .loading
                            && viewStore.previewURLs[index] == nil && (index - 1) % 20 == 0
                        {
                            viewStore.send(.fetchPreviewURLs(index))
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
            .id(viewStore.databaseLoadingState)
        }
        .fullScreenCover(unwrapping: viewStore.binding(\.$route), case: /PreviewsReducer.Route.reading) { _ in
            ReadingView(
                store: store.scope(state: \.readingState, action: PreviewsReducer.Action.reading),
                gid: gid, setting: $setting, blurRadius: blurRadius
            )
            .accentColor(setting.accentColor)
            .autoBlur(radius: blurRadius)
        }
        .onAppear {
            viewStore.send(.fetchDatabaseInfos(gid))
        }
        .navigationTitle(L10n.Localizable.PreviewsView.Title.previews)
    }
}

struct PreviewsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PreviewsView(
                store: .init(
                    initialState: .init(gallery: .preview),
                    reducer: PreviewsReducer()
                ),
                gid: .init(),
                setting: .constant(.init()),
                blurRadius: 0
            )
        }
    }
}
