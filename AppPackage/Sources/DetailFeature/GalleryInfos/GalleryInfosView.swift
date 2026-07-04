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
            Info(title: .metadataId, value: galleryDetail.gid),
            Info(title: .metadataToken, value: gallery.token),
            Info(title: .metadataTitle, value: galleryDetail.title),
            Info(title: .metadataJapaneseTitle, value: galleryDetail.jpnTitle),
            Info(
                title: .metadataGalleryUrl,
                value: gallery.galleryURL?.absoluteString
            ),
            Info(
                title: .metadataCoverUrl,
                value: galleryDetail.coverURL?.absoluteString
            ),
            Info(
                title: .metadataArchiveUrl,
                value: galleryDetail.archiveURL?.absoluteString
            ),
            Info(
                title: .metadataTorrentUrl,
                value: URLUtil.galleryTorrents(gid: gallery.gid, token: gallery.token).absoluteString
            ),
            Info(
                title: .metadataParentUrl,
                value: galleryDetail.parentURL?.absoluteString
            ),
            Info(
                title: .metadataCategory,
                value: String(localized: galleryDetail.category.value)
            ),
            Info(title: .metadataUploader, value: galleryDetail.uploader),
            Info(
                title: .metadataPostedDate,
                value: galleryDetail.formattedDateString
            ),
            Info(
                title: .metadataVisibility,
                value: galleryDetail.visibility.value
            ),
            Info(title: .metadataLanguage, value: galleryDetail.language.value),
            Info(title: .metadataPageCount, value: String(galleryDetail.pageCount)),
            Info(
                title: .metadataFileSize,
                value: String(Int(galleryDetail.sizeCount)) + galleryDetail.sizeType
            ),
            Info(
                title: .metadataFavoritedTimes,
                value: String(galleryDetail.favoritedCount)
            ),
            Info(
                title: .metadataFavorited,
                value: galleryDetail.isFavorited ? String(localized: .metadataYes)
                    : String(localized: .metadataNo)
            ),
            Info(
                title: .metadataRatingCount,
                value: String(galleryDetail.ratingCount)
            ),
            Info(
                title: .metadataAverageRating,
                value: String(Int(galleryDetail.rating))
            ),
            Info(
                title: .metadataMyRating,
                value: galleryDetail.userRating == 0 ? nil : String(Int(galleryDetail.userRating))
            ),
            Info(
                title: .metadataTorrentCount,
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
    var id: Int { String(localized: title).hashValue }
    let title: LocalizedStringResource
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
