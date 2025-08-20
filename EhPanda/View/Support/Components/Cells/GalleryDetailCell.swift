//
//  GalleryDetailCell.swift
//  EhPanda
//

import SwiftUI
import Kingfisher

struct GalleryDetailCell: View {
    @Environment(\.colorScheme) private var colorScheme

    private let gallery: Gallery
    private let setting: Setting
    private let translateAction: ((String) -> (String, TagTranslation?))?

    init(gallery: Gallery, setting: Setting, translateAction: ((String) -> (String, TagTranslation?))? = nil) {
        self.gallery = gallery
        self.setting = setting
        self.translateAction = translateAction
    }

    private var tagColor: Color {
        colorScheme == .light ? Color(.systemGray5) : Color(.systemGray4)
    }

    var body: some View {
        HStack(spacing: 10) {
            KFImage(gallery.coverURL)
                .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.rowAspect)) }
                .defaultModifier().scaledToFit().frame(width: Defaults.ImageSize.rowW, height: Defaults.ImageSize.rowH)
            VStack(alignment: .leading, spacing: 5) {
                Text(gallery.title).lineLimit(3).font(.headline).foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Text(gallery.uploader ?? "").lineLimit(1).font(.subheadline).foregroundStyle(.secondary)
                let tagContents = gallery.tagContents(maximum: setting.listTagsNumberMaximum)
                if setting.showsTagsInList, !tagContents.isEmpty {
                    TagCloudView(data: tagContents) { content in
                        let translation = translateAction?(content.rawNamespace + content.text).1
                        TagCloudCell(
                            text: translation?.displayValue ?? content.text,
                            imageURL: translation?.valueImageURL,
                            showsImages: setting.showsImagesInTags,
                            font: .caption2, padding: .init(top: 2, leading: 4, bottom: 2, trailing: 4),
                            textColor: content.backgroundColor != nil ? content.textColor ?? .secondary : .secondary,
                            backgroundColor: content.backgroundColor ?? tagColor
                        )
                    }
                }
                HStack {
                    RatingView(rating: gallery.rating).font(.caption).foregroundStyle(.yellow)
                    Spacer()
                    HStack(spacing: 10) {
                        Text(gallery.language?.value ?? "")
                        HStack(spacing: 2) {
                            Image(systemSymbol: .photoOnRectangleAngled)
                            Text(String(gallery.pageCount))
                        }
                    }
                    .lineLimit(1).font(.footnote).foregroundStyle(.secondary).minimumScaleFactor(0.75)
                }
                HStack(alignment: .bottom) {
                    CategoryLabel(text: gallery.category.value, color: gallery.color)
                    Spacer()
                    Text(gallery.formattedDateString).lineLimit(1).font(.footnote)
                        .foregroundStyle(.secondary).minimumScaleFactor(0.75)
                }
                .padding(.top, 1)
            }
            .drawingGroup()
        }
        .padding(.vertical, 5).padding(.leading, -10).padding(.trailing, -5)
    }
}

struct GalleryDetailCell_Previews: PreviewProvider {
    static var previews: some View {
        GalleryDetailCell(gallery: .preview, setting: Setting())
    }
}
