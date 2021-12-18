//
//  GalleryThumbnailCell.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/08/02.
//

import SwiftUI
import Kingfisher

struct GalleryThumbnailCell: View {
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
        VStack(alignment: .leading, spacing: 0) {
            KFImage(URL(string: gallery.coverURL))
                .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.rowAspect)) }
                .imageModifier(WebtoonModifier(
                    minAspect: Defaults.ImageSize.webtoonMinAspect,
                    idealAspect: Defaults.ImageSize.webtoonIdealAspect
                ))
                .fade(duration: 0.25).resizable().scaledToFit().overlay {
                    VStack {
                        HStack {
                            Spacer()
                            CategoryLabel(
                                text: category, color: gallery.color,
                                insets: .init(top: 3, leading: 6, bottom: 3, trailing: 6),
                                cornerRadius: 15, corners: .bottomLeft
                            )
                        }
                        Spacer()
                    }
                }
            VStack(alignment: .leading) {
                Text(gallery.title).font(.callout.bold()).lineLimit(3)
                if setting.showsSummaryRowTags, !gallery.tags.isEmpty {
                    TagCloudView(
                        tag: GalleryTag(content: tags), font: .caption2,
                        textColor: .secondary, backgroundColor: tagColor,
                        paddingV: 2, paddingH: 4, translateAction: translateAction
                    )
                    .allowsHitTesting(false)
                }
                HStack {
                    RatingView(rating: gallery.rating).foregroundColor(.yellow).font(.caption)
                    Spacer()
                    HStack(spacing: 10) {
                        if !DeviceUtil.isSEWidth {
                            HStack(spacing: 2) {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text(String(gallery.pageCount))
                            }
                        }
                    }
                    .lineLimit(1).font(.footnote).foregroundStyle(.secondary)
                }
                .padding(.top, 1)
            }
            .padding()
        }
        .background(backgroundColor).cornerRadius(15)
    }
}

private extension GalleryThumbnailCell {
    var category: String {
        gallery.category.rawValue.localized
    }
    var backgroundColor: Color {
        colorScheme == .light ? Color(.systemGray6) : Color(.systemGray5)
    }
    var tagColor: Color {
        colorScheme == .light ? Color(.systemGray5) : Color(.systemGray4)
    }
    var tags: [String] {
        guard setting.summaryRowTagsMaximum > 0 else { return gallery.tags }
        return Array(gallery.tags.prefix(setting.summaryRowTagsMaximum))
    }
}

struct GalleryThumbnailCell_Previews: PreviewProvider {
    static var previews: some View {
        GalleryThumbnailCell(gallery: .preview, setting: Setting())
            .preferredColorScheme(.dark)
    }
}
