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
    private let gid: String
    private let pageCount: Int

    init(store: Store<PreviewsState, PreviewsAction>, gid: String, pageCount: Int) {
        self.store = store
        viewStore = ViewStore(store)
        self.gid = gid
        self.pageCount = pageCount
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
                ForEach(1..<pageCount + 1) { index in
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
                        if viewStore.previews[index] == nil && (index - 1) % 20 == 0 {
                            viewStore.send(.fetchPreviews(index))
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .onAppear {
            viewStore.send(.fetchDatabaseInfos(gid))
        }
        .navigationTitle("Previews")
    }
}

struct PreviewsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            PreviewsView(
                store: .init(
                    initialState: .init(),
                    reducer: previewsReducer,
                    environment: PreviewsEnvironment(
                        databaseClient: .live
                    )
                ),
                gid: .init(),
                pageCount: 1
            )
        }
    }
}
