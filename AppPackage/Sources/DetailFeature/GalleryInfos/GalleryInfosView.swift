import SwiftUI
import AppModels
import Resources
import ComposableArchitecture
import AppTools
import SystemNotificationExt

struct GalleryInfosView: View {
    @Bindable private var store: StoreOf<GalleryInfosReducer>
    private let gallery: Gallery
    private let galleryDetail: GalleryDetail

    init(store: StoreOf<GalleryInfosReducer>, gallery: Gallery, galleryDetail: GalleryDetail) {
        self.store = store
        self.gallery = gallery
        self.galleryDetail = galleryDetail
    }

    private var infos: [Info] {
        [
            Info(title: L10n.Localizable.GalleryInfosView.id, value: galleryDetail.gid),
            Info(title: L10n.Localizable.GalleryInfosView.token, value: gallery.token),
            Info(title: L10n.Localizable.GalleryInfosView.title, value: galleryDetail.title),
            Info(title: L10n.Localizable.GalleryInfosView.japaneseTitle, value: galleryDetail.jpnTitle),
            Info(
                title: L10n.Localizable.GalleryInfosView.galleryURL,
                value: gallery.galleryURL?.absoluteString
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.coverURL,
                value: galleryDetail.coverURL?.absoluteString
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.archiveURL,
                value: galleryDetail.archiveURL?.absoluteString
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.torrentURL,
                value: URLUtil.galleryTorrents(gid: gallery.gid, token: gallery.token).absoluteString
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.parentURL,
                value: galleryDetail.parentURL?.absoluteString
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.category,
                value: galleryDetail.category.value
            ),
            Info(title: L10n.Localizable.GalleryInfosView.uploader, value: galleryDetail.uploader),
            Info(
                title: L10n.Localizable.GalleryInfosView.postedDate,
                value: galleryDetail.formattedDateString
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.visibility,
                value: galleryDetail.visibility.value
            ),
            Info(title: L10n.Localizable.GalleryInfosView.language, value: galleryDetail.language.value),
            Info(title: L10n.Localizable.GalleryInfosView.pageCount, value: String(galleryDetail.pageCount)),
            Info(
                title: L10n.Localizable.GalleryInfosView.fileSize,
                value: String(Int(galleryDetail.sizeCount)) + galleryDetail.sizeType
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.favoritedTimes,
                value: String(galleryDetail.favoritedCount)
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.favorited,
                value: galleryDetail.isFavorited ? L10n.Localizable.GalleryInfosView.yes
                    : L10n.Localizable.GalleryInfosView.no
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.ratingCount,
                value: String(galleryDetail.ratingCount)
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.averageRating,
                value: String(Int(galleryDetail.rating))
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.myRating,
                value: galleryDetail.userRating == 0 ? nil : String(Int(galleryDetail.userRating))
            ),
            Info(
                title: L10n.Localizable.GalleryInfosView.torrentCount,
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
                            store.send(.copyText(text))
                        }
                    } label: {
                        Text(info.value ?? L10n.Localizable.GalleryInfosView.none)
                            .lineLimit(3).font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .toast($store.scope(state: \.toast, action: \.toast))
        .navigationTitle(L10n.Localizable.GalleryInfosView.galleryInfos)
    }
}

private struct Info: Identifiable {
    var id: Int { title.hashValue }
    let title: String
    let value: String?
}

struct GalleryInfosView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            GalleryInfosView(
                store: .init(initialState: .init(), reducer: GalleryInfosReducer.init),
                gallery: .preview,
                galleryDetail: .preview
            )
        }
    }
}
