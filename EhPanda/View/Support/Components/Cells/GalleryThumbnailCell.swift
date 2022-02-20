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
    private let translateAction: ((String) -> (String, TagTranslation?))?

    init(gallery: Gallery, setting: Setting, translateAction: ((String) -> (String, TagTranslation?))? = nil) {
        self.gallery = gallery
        self.setting = setting
        self.translateAction = translateAction
    }

    private var backgroundColor: Color {
        colorScheme == .light ? Color(.systemGray6) : Color(.systemGray5)
    }
    private var tagColor: Color {
        colorScheme == .light ? Color(.systemGray5) : Color(.systemGray4)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            KFImage(gallery.coverURL)
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
                                text: gallery.category.value, color: gallery.color,
                                insets: .init(top: 3, leading: 6, bottom: 3, trailing: 6),
                                cornerRadius: 15, corners: .bottomLeft
                            )
                        }
                        Spacer()
                    }
                }
            VStack(alignment: .leading, spacing: 5) {
                Text(gallery.title).font(.callout.bold()).lineLimit(3)
                let tagContents = gallery.tagContents(maximum: setting.listTagsNumberMaximum)
                if setting.showsTagsInList, !tagContents.isEmpty {
                    TagCloudView(data: gallery.tagContents(maximum: setting.listTagsNumberMaximum)) { content in
                        TagCloudCell(
                            text: content.localizedDisplayText(translateAction: translateAction),
                            imageURL: translateAction?(content.text).1?.valueImageURL,
                            showsImages: setting.showsImagesInTags,
                            font: .caption2, padding: .init(top: 2, leading: 4, bottom: 2, trailing: 4),
                            textColor: content.backgroundColor != nil ? .white : .secondary,
                            backgroundColor: content.backgroundColor ?? tagColor
                        )
                    }
                }
                HStack(spacing: 10) {
                    if let language = gallery.language {
                        Text(language.value)
                    }
                    HStack(spacing: 2) {
                        Image(systemSymbol: .photoOnRectangleAngled)
                        Text(String(gallery.pageCount))
                    }
                }
                .lineLimit(1).font(.footnote).foregroundStyle(.secondary)
                RatingView(rating: gallery.rating).foregroundColor(.yellow).font(.caption)
            }
            .padding()
        }
        .background(backgroundColor).cornerRadius(15)
    }
}

struct GalleryThumbnailCell_Previews: PreviewProvider {
    static var previews: some View {
        GalleryThumbnailCell(gallery: .preview, setting: Setting())
            .preferredColorScheme(.dark)
    }
}
