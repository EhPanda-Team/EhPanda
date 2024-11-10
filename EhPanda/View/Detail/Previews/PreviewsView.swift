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
    @Bindable private var store: StoreOf<PreviewsReducer>
    private let gid: String
    @Binding private var setting: Setting
    private let blurRadius: Double

    init(
        store: StoreOf<PreviewsReducer>,
        gid: String, setting: Binding<Setting>, blurRadius: Double
    ) {
        self.store = store
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
                ForEach(1..<store.gallery.pageCount + 1, id: \.self) { index in
                    VStack {
                        let (url, modifier) = PreviewResolver.getPreviewConfigs(
                            originalURL: store.previewURLs[index]
                        )
                        Button {
                            store.send(.updateReadingProgress(index))
                            store.send(.setNavigation(.reading()))
                        } label: {
                            KFImage.url(url, cacheKey: store.previewURLs[index]?.absoluteString)
                                .placeholder({ Placeholder(style: .activity(ratio: Defaults.ImageSize.previewAspect)) })
                                .imageModifier(modifier)
                                .fade(duration: 0.25)
                                .resizable()
                                .scaledToFit()
                        }
                        Text("\(index)")
                            .font(DeviceUtil.isPadWidth ? .callout : .caption)
                            .foregroundColor(.secondary)
                    }
                    .onAppear {
                        if store.databaseLoadingState != .loading
                            && store.previewURLs[index] == nil && (index - 1) % 10 == 0
                        {
                            store.send(.fetchPreviewURLs(index))
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
            .id(store.databaseLoadingState)
        }
        .fullScreenCover(item: $store.route.sending(\.setNavigation).reading) { _ in
            ReadingView(
                store: store.scope(state: \.readingState, action: \.reading),
                gid: gid, setting: $setting, blurRadius: blurRadius
            )
            .accentColor(setting.accentColor)
            .autoBlur(radius: blurRadius)
        }
        .onAppear {
            store.send(.fetchDatabaseInfos(gid))
        }
        .navigationTitle(L10n.Localizable.PreviewsView.Title.previews)
    }
}

struct PreviewsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PreviewsView(
                store: .init(initialState: .init(gallery: .preview), reducer: PreviewsReducer.init),
                gid: .init(),
                setting: .constant(.init()),
                blurRadius: 0
            )
        }
    }
}
