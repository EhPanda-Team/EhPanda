import SwiftUI
import AppModels
import Resources
import ComposableArchitecture
import AppComponents
import ReadingFeature

struct PreviewsView: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    @Bindable private var store: StoreOf<PreviewsReducer>

    init(store: StoreOf<PreviewsReducer>) {
        self.store = store
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
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollTargetLayout()
            .padding(.horizontal)
            .padding(.bottom)
        }
        .fullScreenCover(
            item: $store.scope(\.$destination, action: \.destination).reading
        ) { store in
            ReadingView(store: store)
            .privacyMask()
        }
        // Paged lazy loading, driven by what is actually on screen rather than by each cell's
        // appearance. Preview URLs arrive ten at a time, so only every tenth index triggers a fetch;
        // the first page is requested by the reducer on presentation.
        .onScrollTargetVisibilityChange(idType: Int.self) { indices in
            for index in indices where displayPreviewURLs[index] == nil && (index - 1) % 10 == 0 {
                store.send(.fetchPreviewURLs(index))
            }
        }
        .navigationTitle(.previews)
    }
}

#Preview("Loaded") {
    NavigationStack {
        PreviewsView(
            store: .init(initialState: .init(gallery: .preview), reducer: PreviewsReducer.init)
        )
    }
}
