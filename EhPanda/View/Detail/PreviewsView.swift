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
    private let store: Store<PreviewsState, PreviewsAction>
    @ObservedObject private var viewStore: ViewStore<PreviewsState, PreviewsAction>
    @Binding private var setting: Setting
    private let blurRadius: Double

    init(
        store: Store<PreviewsState, PreviewsAction>,
        setting: Binding<Setting>, blurRadius: Double
    ) {
        self.store = store
        viewStore = ViewStore(store)
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
                ForEach(1..<viewStore.gallery.pageCount + 1) { index in
                    VStack {
                        let (url, modifier) = PreviewResolver.getPreviewConfigs(
                            originalURL: viewStore.previews[index] ?? ""
                        )
                        Button {
                            viewStore.send(.updateReadingProgress(index))
                            viewStore.send(.setNavigation(.reading))
                        } label: {
                            KFImage.url(URL(string: url), cacheKey: viewStore.previews[index])
                                .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.previewAspect)) }
                                .imageModifier(modifier).fade(duration: 0.25).resizable().scaledToFit()
                        }
                        Text("\(index)").font(DeviceUtil.isPadWidth ? .callout : .caption).foregroundColor(.secondary)
                    }
                    .onAppear {
                        if viewStore.databaseLoadingState != .loading
                            && viewStore.previews[index] == nil && (index - 1) % 20 == 0
                        {
                            viewStore.send(.fetchPreviews(index))
                        }
                    }
                }
                .id(viewStore.databaseLoadingState)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .fullScreenCover(unwrapping: viewStore.binding(\.$route), case: /PreviewsState.Route.reading) { _ in
            ReadingView(
                store: store.scope(state: \.readingState, action: PreviewsAction.reading),
                setting: $setting, blurRadius: blurRadius,
                dismissAction: { viewStore.send(.setNavigation(nil)) }
            )
            .accentColor(setting.accentColor)
            .autoBlur(radius: blurRadius)
        }
        .onAppear {
            viewStore.send(.fetchDatabaseInfos)
        }
        .navigationTitle(R.string.localizable.commentsViewTitlePreviews())
    }
}

struct PreviewsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PreviewsView(
                store: .init(
                    initialState: .init(gallery: .preview),
                    reducer: previewsReducer,
                    environment: PreviewsEnvironment(
                        urlClient: .live,
                        imageClient: .live,
                        deviceClient: .live,
                        hapticClient: .live,
                        databaseClient: .live,
                        clipboardClient: .live,
                        appDelegateClient: .live
                    )
                ),
                setting: .constant(.init()),
                blurRadius: 0
            )
        }
    }
}
