//
//  GalleryInfosView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/08/15.
//

import SwiftUI
import TTProgressHUD
import ComposableArchitecture

struct GalleryInfosView: View {
    private let store: Store<GalleryInfosState, GalleryInfosAction>
    @ObservedObject private var viewStore: ViewStore<GalleryInfosState, GalleryInfosAction>
    private let gallery: Gallery
    private let galleryDetail: GalleryDetail

    init(store: Store<GalleryInfosState, GalleryInfosAction>, gallery: Gallery, galleryDetail: GalleryDetail) {
        self.store = store
        viewStore = ViewStore(store)
        self.gallery = gallery
        self.galleryDetail = galleryDetail
    }

    private var infos: [Info] {
        [
            Info(title: "ID", value: galleryDetail.gid),
            Info(title: "Token", value: gallery.token),
            Info(title: "Title", value: galleryDetail.title),
            Info(title: "Japanese title", value: galleryDetail.jpnTitle),
            Info(title: "Gallery URL", value: gallery.galleryURL),
            Info(title: "Cover URL", value: galleryDetail.coverURL),
            Info(title: "Archive URL", value: galleryDetail.archiveURL),
            Info(title: "Torrent URL", value: URLUtil.galleryTorrents(
                gid: gallery.gid, token: gallery.token).absoluteString),
            Info(title: "Parent URL", value: galleryDetail.parentURL),
            Info(title: "Category", value: galleryDetail.category.rawValue.localized),
            Info(title: "Uploader", value: galleryDetail.uploader),
            Info(title: "Posted date", value: galleryDetail.formattedDateString),
            Info(title: "Visible", value: galleryDetail.visibility.value.localized),
            Info(title: "Language", value: galleryDetail.language.name.localized),
            Info(title: "Page count", value: String(galleryDetail.pageCount)),
            Info(title: "File size", value: String(Int(galleryDetail.sizeCount)) + galleryDetail.sizeType),
            Info(title: "Favorited times", value: String(galleryDetail.favoredCount)),
            Info(title: "Favorited", value: (galleryDetail.isFavored ? "Yes" : "No").localized),
            Info(title: "Rating count", value: String(galleryDetail.ratingCount)),
            Info(title: "Average rating", value: String(Int(galleryDetail.rating))),
            Info(title: "User rating", value:
                galleryDetail.userRating == 0 ? nil : String(Int(galleryDetail.userRating))),
            Info(title: "Torrent count", value: String(galleryDetail.torrentCount))
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            List(infos) { info in
                HStack {
                    HStack {
                        Text(info.title.localized)
                        Spacer()
                    }
                    .frame(width: proxy.size.width / 3)
                    Spacer()
                    Button {
                        if let text = info.value {
                            viewStore.send(.copyText(text))
                        }
                    } label: {
                        Text(info.value ?? "null".localized)
                            .lineLimit(3).font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .progressHUD(
            config: viewStore.hudConfig,
            unwrapping: viewStore.binding(\.$route),
            case: /GalleryInfosState.Route.hud
        )
        .navigationTitle("Gallery infos")
    }
}

private struct Info: Identifiable {
    var id: Int { title.hashValue }
    let title: String
    let value: String?
}

struct GalleryInfosView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            GalleryInfosView(
                store: .init(
                    initialState: .init(),
                    reducer: galleryInfosReducer,
                    environment: GalleryInfosEnvironment(
                        hapticClient: .live,
                        clipboardClient: .live
                    )
                ),
                gallery: .preview,
                galleryDetail: .preview
            )
        }
    }
}
