//
//  GalleryDetailCell.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/16.
//

import SwiftUI
import Kingfisher

struct GalleryDetailCell: View {
    @Environment(\.colorScheme) private var colorScheme

    private let gallery: Gallery
    private let setting: Setting
    private let translateAction: ((String) -> String)?

    init(gallery: Gallery, setting: Setting, translateAction: ((String) -> String)? = nil) {
        self.gallery = gallery
        self.setting = setting
        self.translateAction = translateAction
    }

    var body: some View {
        HStack(spacing: 10) {
            KFImage(URL(string: gallery.coverURL))
                .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.rowScale)) }
                .defaultModifier().scaledToFit().frame(width: Defaults.ImageSize.rowW, height: Defaults.ImageSize.rowH)
            VStack(alignment: .leading) {
                Text(gallery.title).lineLimit(1).font(.headline).foregroundStyle(.primary)
                Text(gallery.uploader ?? "").lineLimit(1).font(.subheadline).foregroundStyle(.secondary)
                if setting.showsSummaryRowTags, !tags.isEmpty {
                    TagCloudView(
                        tag: GalleryTag(category: .artist, content: tags), font: .caption2,
                        textColor: .secondary, backgroundColor: tagColor,
                        paddingV: 2, paddingH: 4, translateAction: translateAction
                    )
                    .allowsHitTesting(false)
                }
                HStack {
                    RatingView(rating: gallery.rating).font(.caption).foregroundStyle(.yellow)
                    Spacer()
                    HStack(spacing: 10) {
                        Text(gallery.language?.rawValue.localized ?? "")
                        HStack(spacing: 2) {
                            Image(systemName: "photo.on.rectangle.angled")
                            Text(String(gallery.pageCount))
                        }
                    }
                    .lineLimit(1).font(.footnote).foregroundStyle(.secondary).minimumScaleFactor(0.75)
                }
                HStack(alignment: .bottom) {
                    CategoryLabel(text: category, color: gallery.color)
                    Spacer()
                    Text(gallery.formattedDateString).lineLimit(1).font(.footnote)
                        .foregroundStyle(.secondary).minimumScaleFactor(0.75)
                }
                .padding(.top, 1)
            }
            .drawingGroup()
        }
        .padding(.vertical, setting.showsSummaryRowTags ? 5 : 0).padding(.leading, -10).padding(.trailing, -5)
    }
}

private extension GalleryDetailCell {
    var category: String {
        gallery.category.rawValue.localized
    }
    var tags: [String] {
        guard setting.summaryRowTagsMaximum > 0 else { return gallery.tags }
        return Array(gallery.tags.prefix(setting.summaryRowTagsMaximum))
    }
    var tagColor: Color {
        colorScheme == .light ? Color(.systemGray5) : Color(.systemGray4)
    }
}

struct GalleryDetailCell_Previews: PreviewProvider {
    static var previews: some View {
        GalleryDetailCell(gallery: .preview, setting: Setting()).preferredColorScheme(.dark)
    }
}
