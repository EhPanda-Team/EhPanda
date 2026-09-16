import AppModels
import AppTools
import ComposableArchitecture
import Resources
import SwiftUI
import SystemNotification

struct GalleryInfosView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Bindable private var store: StoreOf<GalleryInfosReducer>
    @SharedReader(.setting) private var setting: Setting
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
                value: URLUtil.galleryTorrents(
                    host: setting.galleryHost,
                    gid: gallery.gid,
                    token: gallery.token
                ).absoluteString
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
            Info(title: .metadataLanguage, value: String(localized: galleryDetail.language.value)),
            Info(title: .metadataPageCount, value: String(galleryDetail.pageCount)),
            Info(
                title: .metadataFileSize,
                value: String(Int(galleryDetail.sizeCount)) + galleryDetail.sizeType,
                accessibilityValue: galleryDetail
                    .accessibilitySizeUnit(quantity: Double(Int(galleryDetail.sizeCount)))
                    .map { String(Int(galleryDetail.sizeCount)) + " " + $0 }
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

    /// Every value on this screen is a URL, an identifier or a title — a string whose meaning lives
    /// in the tail a cap removes first, and one the row exists to let the reader copy. Above the
    /// default size the cap is lifted, so the row grows and the whole token reads; at and below it
    /// the designed three-line budget is kept verbatim. The title beside the value stays flexible
    /// and the row flips to a stack as soon as the pair no longer fits a line, so an uncapped value
    /// wraps across the full width rather than into a narrow trailing column.
    private var valueLineLimit: Int? {
        dynamicTypeSize <= .large ? 3 : nil
    }

    /// The row keeps its designed look — the title, and the value as the copy button (owner
    /// decision, 2026-09-15) — and is one accessibility element: named by the title and carrying the
    /// value, so VoiceOver reads "Gallery URL, https://…" and activates the copy, instead of a bare
    /// URL or identifier as the button's name (the audit's "label not human-readable").
    var body: some View {
        List(infos) { info in
            ViewThatFits(in: .horizontal) {
                HStack {
                    Text(info.title)
                        .lineLimit(1)
                        .fixedSize(horizontal: true, vertical: false)
                    Spacer()
                    content(for: info, lineLimit: 1)
                        .fixedSize(horizontal: true, vertical: false)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text(info.title)
                    content(for: info, lineLimit: valueLineLimit)
                }
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel(info.title)
            .accessibilityValue(info.accessibilityValue ?? valueText(for: info))
        }
        .toast($store.scope(\.$toast, action: \.toast))
        .navigationTitle(.metadataGalleryInfos)
    }

    private func content(for info: Info, lineLimit: Int?) -> some View {
        Button {
            if let text = info.value {
                store.send(.copyText(text))
            }
        } label: {
            Text(valueText(for: info))
                .lineLimit(lineLimit)
                .font(.caption)
        }
    }

    private func valueText(for info: Info) -> String {
        info.value ?? String(localized: .metadataNone)
    }
}

private struct Info: Identifiable {
    var id: Int { String(localized: title).hashValue }
    let title: LocalizedStringResource
    let value: String?
    let accessibilityValue: String?

    init(
        title: LocalizedStringResource,
        value: String?,
        accessibilityValue: String? = nil
    ) {
        self.title = title
        self.value = value
        self.accessibilityValue = accessibilityValue
    }
}

#Preview("Loaded") {
    NavigationStack {
        GalleryInfosView(
            store: .init(
                initialState: .init(gallery: .preview, galleryDetail: .preview),
                reducer: GalleryInfosReducer.init
            ),
            gallery: .preview,
            galleryDetail: .preview
        )
    }
}
