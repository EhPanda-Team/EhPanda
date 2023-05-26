//
//  GalleryInfosView.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/08/15.
//

import SwiftUI
import ComposableArchitecture

struct GalleryInfosView: View {
    private let store: StoreOf<GalleryInfosReducer>
    @ObservedObject private var viewStore: ViewStoreOf<GalleryInfosReducer>
    private let gallery: Gallery
    private let galleryDetail: GalleryDetail

    init(store: StoreOf<GalleryInfosReducer>, gallery: Gallery, galleryDetail: GalleryDetail) {
        self.store = store
        viewStore = ViewStore(store)
        self.gallery = gallery
        self.galleryDetail = galleryDetail
    }

    private var infos: [Info] {
        [
            Info(title: L10n.Localizable.GalleryInfosView.Title.id, value: galleryDetail.gid),
            Info(title: L10n.Localizable.GalleryInfosView.Title.token, value: gallery.token),
            Info(title: L10n.Localizable.GalleryInfosView.Title.title, value: galleryDetail.title),
            Info(title: L10n.Localizable.GalleryInfosView.Title.japaneseTitle, value: galleryDetail.jpnTitle),
            Info(
                title: L10n.Localizable.GalleryInfosView.Title.galleryURL,
                value: gallery.galleryURL?.absoluteString
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.Title.coverURL,
                value: galleryDetail.coverURL?.absoluteString
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.Title.archiveURL,
                value: galleryDetail.archiveURL?.absoluteString
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.Title.torrentURL,
                value: URLUtil.galleryTorrents(gid: gallery.gid, token: gallery.token).absoluteString
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.Title.parentURL,
                value: galleryDetail.parentURL?.absoluteString
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.Title.category,
                value: galleryDetail.category.value
            ),
            Info(title: L10n.Localizable.GalleryInfosView.Title.uploader, value: galleryDetail.uploader),
            Info(
                title: L10n.Localizable.GalleryInfosView.Title.postedDate,
                value: galleryDetail.formattedDateString
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.Title.visibility,
                value: galleryDetail.visibility.value
            ),
            Info(title: L10n.Localizable.GalleryInfosView.Title.language, value: galleryDetail.language.value),
            Info(title: L10n.Localizable.GalleryInfosView.Title.pageCount, value: String(galleryDetail.pageCount)),
            Info(
                title: L10n.Localizable.GalleryInfosView.Title.fileSize,
                value: String(Int(galleryDetail.sizeCount)) + galleryDetail.sizeType
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.Title.favoritedTimes,
                value: String(galleryDetail.favoritedCount)
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.Title.favorited,
                value: galleryDetail.isFavorited ? L10n.Localizable.GalleryInfosView.Value.yes
                : L10n.Localizable.GalleryInfosView.Value.no
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.Title.ratingCount,
                value: String(galleryDetail.ratingCount)
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.Title.averageRating,
                value: String(Int(galleryDetail.rating))
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.Title.myRating,
                value: galleryDetail.userRating == 0 ? nil : String(Int(galleryDetail.userRating))
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.Title.torrentCount,
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
                        Text(info.value ?? L10n.Localizable.GalleryInfosView.Value.none)
                            .lineLimit(3).font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .progressHUD(
            config: viewStore.hudConfig,
            unwrapping: viewStore.binding(\.$route),
            case: /GalleryInfosReducer.Route.hud
        )
        .navigationTitle(L10n.Localizable.GalleryInfosView.Title.galleryInfos)
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
                    reducer: GalleryInfosReducer()
                ),
                gallery: .preview,
                galleryDetail: .preview
            )
        }
    }
}
