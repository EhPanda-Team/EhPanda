import SwiftUI
import AppModels
import Resources
import ComposableArchitecture
import AppComponents
import ReadingFeature

struct PreviewsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Bindable private var store: StoreOf<PreviewsReducer>
    private let gid: String

    init(
        store: StoreOf<PreviewsReducer>,
        gid: String
    ) {
        self.store = store
        self.gid = gid
    }

    private var gridItems: [GridItem] {
        [GridItem(
            .adaptive(
                minimum: DetailLayout.previewGridMinimumWidth(
                    regular: horizontalSizeClass == .regular
                ),
                maximum: DetailLayout.previewGridMaximumWidth(
                    regular: horizontalSizeClass == .regular
                )
            ),
            spacing: 10
        )]
    }

    var body: some View {
        let displayPreviewURLs = store.localPreviewURLs.merging(
            store.previewURLs,
            uniquingKeysWith: { local, _ in local }
        )
        ScrollView {
            LazyVGrid(columns: gridItems) {
                ForEach(1..<store.gallery.pageCount + 1, id: \.self) { index in
                    VStack {
                        Button {
                            store.send(.updateReadingProgress(index))
                            store.send(.openReading(index))
                        } label: {
                            PreviewImageView(originalURL: displayPreviewURLs[index])
                        }
                        Text(index, format: .number)
                            .font(horizontalSizeClass == .regular ? .callout : .caption)
                            .foregroundColor(.secondary)
                    }
                    .onAppear {
                        if displayPreviewURLs[index] == nil && (index - 1) % 10 == 0 {
                            store.send(.fetchPreviewURLs(index))
                        }
                    }
                }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .fullScreenCover(
            item: $store.scope(\.$destination, action: \.destination).reading
        ) { store in
            ReadingView(
                store: store,
                gid: store.gallery.id
            )
            .accentColor(store.setting.accentColor)
            .privacyMask()
        }
        .onAppear {
            store.send(.onAppear(gid))
        }
        .navigationTitle(.previews)
    }
}

struct PreviewsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            PreviewsView(
                store: .init(initialState: .init(gallery: .preview), reducer: PreviewsReducer.init),
                gid: .init()
            )
        }
    }
}
