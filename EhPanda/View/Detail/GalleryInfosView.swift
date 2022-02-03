//
//  GalleryInfosView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/08/15.
//

import SwiftUI
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
            Info(title: R.string.localizable.galleryInfosViewTitleTitle(), value: galleryDetail.title),
            Info(title: R.string.localizable.galleryInfosViewTitleJapaneseTitle(), value: galleryDetail.jpnTitle),
            Info(
                title: R.string.localizable.galleryInfosViewTitleGalleryURL(),
                value: gallery.galleryURL?.absoluteString
            ),
            Info(
                title: R.string.localizable.galleryInfosViewTitleCoverURL(),
                value: galleryDetail.coverURL?.absoluteString
            ),
            Info(
                title: R.string.localizable.galleryInfosViewTitleArchiveURL(),
                value: galleryDetail.archiveURL?.absoluteString
            ),
            Info(
                title: R.string.localizable.galleryInfosViewTitleTorrentURL(),
                value: URLUtil.galleryTorrents(gid: gallery.gid, token: gallery.token).absoluteString
            ),
            Info(
                title: R.string.localizable.galleryInfosViewTitleParentURL(),
                value: galleryDetail.parentURL?.absoluteString
            ),
            Info(
                title: R.string.localizable.galleryInfosViewTitleCategory(),
                value: galleryDetail.category.value
            ),
            Info(title: R.string.localizable.galleryInfosViewTitleUploader(), value: galleryDetail.uploader),
            Info(
                title: R.string.localizable.galleryInfosViewTitlePostedDate(),
                value: galleryDetail.formattedDateString
            ),
            Info(
                title: R.string.localizable.galleryInfosViewTitleVisibility(),
                value: galleryDetail.visibility.value
            ),
            Info(title: R.string.localizable.galleryInfosViewTitleLanguage(), value: galleryDetail.language.value),
            Info(title: R.string.localizable.galleryInfosViewTitlePageCount(), value: String(galleryDetail.pageCount)),
            Info(
                title: R.string.localizable.galleryInfosViewTitleFileSize(),
                value: String(Int(galleryDetail.sizeCount)) + galleryDetail.sizeType
            ),
            Info(
                title: R.string.localizable.galleryInfosViewTitleFavoritedTimes(),
                value: String(galleryDetail.favoritedCount)
            ),
            Info(
                title: R.string.localizable.galleryInfosViewTitleFavorited(),
                value: galleryDetail.isFavorited ? R.string.localizable.galleryInfosViewValueYes()
                : R.string.localizable.galleryInfosViewValueNo()
            ),
            Info(
                title: R.string.localizable.galleryInfosViewTitleRatingCount(),
                value: String(galleryDetail.ratingCount)
            ),
            Info(
                title: R.string.localizable.galleryInfosViewTitleAverageRating(),
                value: String(Int(galleryDetail.rating))
            ),
            Info(
                title: R.string.localizable.galleryInfosViewTitleMyRating(),
                value: galleryDetail.userRating == 0 ? nil : String(Int(galleryDetail.userRating))
            ),
            Info(
                title: R.string.localizable.galleryInfosViewTitleTorrentCount(),
                value: String(galleryDetail.torrentCount)
            )
        ]
    }

    var body: some View {
        GeometryReader { proxy in
            List(infos) { info in
                HStack {
                    HStack {
                        Text(info.title)
                        Spacer()
                    }
                    .frame(width: proxy.size.width / 3)
                    Spacer()
                    Button {
                        if let text = info.value {
                            viewStore.send(.copyText(text))
                        }
                    } label: {
                        Text(info.value ?? R.string.localizable.galleryInfosViewValueNone())
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
        .navigationTitle(R.string.localizable.galleryInfosViewTitleGalleryInfos())
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
