//
//  GalleryThumbnailCell.swift
//  EhPanda
//
//  Created by 荒木辰造 on 2021/08/02.
//

import SwiftUI
import Kingfisher

struct GalleryThumbnailCell: View {
    @Environment(\.colorScheme) private var colorScheme

    private let gallery: Gallery
    private let setting: Setting
    private let translateAction: ((String) -> String)?

    init(
        gallery: Gallery, setting: Setting,
        translateAction: ((String) -> String)? = nil
    ) {
        self.gallery = gallery
        self.setting = setting
        self.translateAction = translateAction
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            KFImage(URL(string: gallery.coverURL))
                .placeholder {
                    Placeholder(
                        style: .activity(
                            ratio: Defaults.ImageSize
                                .rowScale
                        )
                    )
                }
                .fade(duration: 0.25)
                .resizable()
                .scaledToFit()
                .overlay {
                    VStack {
                        HStack {
                            Spacer()
                            CategoryLabel(
                                text: category,
                                color: gallery.color,
                                insets: .init(
                                    top: 3, leading: 6,
                                    bottom: 3, trailing: 6
                                ),
                                cornerRadius: 15,
                                corners: .bottomLeft
                            )
                        }
                        Spacer()
                    }
                }
            VStack(alignment: .leading) {
                Text(gallery.title).bold()
                    .font(.callout)
                    .lineLimit(3)
                if setting.showsSummaryRowTags, !gallery.tags.isEmpty {
                    TagCloudView(
                        tag: GalleryTag(
                            category: .artist,
                            content: gallery.tags
                        ),
                        font: .caption2,
                        textColor: .secondary,
                        backgroundColor: tagColor,
                        paddingV: 2, paddingH: 4,
                        translateAction: translateAction
                    )
                    .allowsHitTesting(false)
                }
                HStack {
                    RatingView(rating: gallery.rating)
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Spacer()
                    HStack(spacing: 10) {
                        Text(gallery.language?.languageAbbr ?? "")
                        if !isSEWidth {
                            HStack(spacing: 2) {
                                Image(systemName: "photo.on.rectangle.angled")
                                Text(String(gallery.pageCount))
                            }
                        }
                    }
                    .fixedSize().lineLimit(1).font(.footnote)
                    .foregroundStyle(.secondary)
                }
                .padding(.top, 1)
            }
            .padding()
        }
        .background(backgroundColor)
        .cornerRadius(15)
    }
}

private extension GalleryThumbnailCell {
    var category: String {
        gallery.category.rawValue.localized()
    }
    var backgroundColor: Color {
        colorScheme == .light
        ? Color(.systemGray6)
        : Color(.systemGray5)
    }
    var tagColor: Color {
        colorScheme == .light
        ? Color(.systemGray5)
        : Color(.systemGray4)
    }
}

struct GalleryThumbnailCell_Previews: PreviewProvider {
    static var previews: some View {
        GalleryThumbnailCell(gallery: .preview, setting: Setting())
            .preferredColorScheme(.dark)
    }
}
