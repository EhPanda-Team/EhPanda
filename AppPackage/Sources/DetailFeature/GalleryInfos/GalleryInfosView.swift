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
            Info(title: String(localized: .metadataId), value: galleryDetail.gid),
            Info(title: String(localized: .metadataToken), value: gallery.token),
            Info(title: String(localized: .metadataTitle), value: galleryDetail.title),
            Info(title: String(localized: .metadataJapaneseTitle), value: galleryDetail.jpnTitle),
            Info(
                title: String(localized: .metadataGalleryUrl),
                value: gallery.galleryURL?.absoluteString
            ),
            Info(
                title: String(localized: .metadataCoverUrl),
                value: galleryDetail.coverURL?.absoluteString
            ),
            Info(
                title: String(localized: .metadataArchiveUrl),
                value: galleryDetail.archiveURL?.absoluteString
            ),
            Info(
                title: String(localized: .metadataTorrentUrl),
                value: URLUtil.galleryTorrents(gid: gallery.gid, token: gallery.token).absoluteString
            ),
            Info(
                title: String(localized: .metadataParentUrl),
                value: galleryDetail.parentURL?.absoluteString
            ),
            Info(
                title: String(localized: .metadataCategory),
                value: galleryDetail.category.value
            ),
            Info(title: String(localized: .metadataUploader), value: galleryDetail.uploader),
            Info(
                title: String(localized: .metadataPostedDate),
                value: galleryDetail.formattedDateString
            ),
            Info(
                title: String(localized: .metadataVisibility),
                value: galleryDetail.visibility.value
            ),
            Info(title: String(localized: .metadataLanguage), value: galleryDetail.language.value),
            Info(title: String(localized: .metadataPageCount), value: String(galleryDetail.pageCount)),
            Info(
                title: String(localized: .metadataFileSize),
                value: String(Int(galleryDetail.sizeCount)) + galleryDetail.sizeType
            ),
            Info(
                title: String(localized: .metadataFavoritedTimes),
                value: String(galleryDetail.favoritedCount)
            ),
            Info(
                title: String(localized: .metadataFavorited),
                value: galleryDetail.isFavorited ? String(localized: .metadataYes)
                    : String(localized: .metadataNo)
            ),
            Info(
                title: String(localized: .metadataRatingCount),
                value: String(galleryDetail.ratingCount)
            ),
            Info(
                title: String(localized: .metadataAverageRating),
                value: String(Int(galleryDetail.rating))
            ),
            Info(
                title: String(localized: .metadataMyRating),
                value: galleryDetail.userRating == 0 ? nil : String(Int(galleryDetail.userRating))
            ),
            Info(
                title: String(localized: .metadataTorrentCount),
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
                        Text(info.value ?? String(localized: .metadataNone))
                            .lineLimit(3).font(.caption)
                            .foregroundStyle(.tint)
                    }
                }
            }
        }
        .toast($store.scope(state: \.toast, action: \.toast))
        .navigationTitle(.metadataGalleryInfos)
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
