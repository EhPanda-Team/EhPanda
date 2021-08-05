//
//  MangaDetailCell.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/16.
//

import SwiftUI
import Kingfisher

struct MangaDetailCell: View {
    @Environment(\.colorScheme) private var colorScheme

    private let manga: Manga
    private let setting: Setting
    private let translateAction: ((String) -> String)?

    init(
        manga: Manga,
        setting: Setting,
        translateAction: ((String) -> String)? = nil
    ) {
        self.manga = manga
        self.setting = setting
        self.translateAction = translateAction
    }

    var body: some View {
        HStack(spacing: 10) {
            KFImage(URL(string: manga.coverURL))
                .placeholder {
                    Placeholder(style: .activity(
                        ratio: Defaults.ImageSize
                            .rowScale
                    ))
                }
                .defaultModifier()
                .scaledToFit()
                .frame(width: width, height: height)
            VStack(alignment: .leading) {
                Text(manga.title)
                    .lineLimit(1)
                    .font(.headline)
                    .foregroundStyle(.primary)
                Text(manga.uploader ?? "")
                    .lineLimit(1)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if setting.showsSummaryRowTags, !tags.isEmpty {
                    TagCloudView(
                        tag: MangaTag(
                            category: .artist,
                            content: tags
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
                    RatingView(rating: manga.rating)
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Spacer()
                    Text(manga.language?.rawValue.localized() ?? "")
                        .lineLimit(1)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .bottom) {
                    CategoryLabel(text: category, color: manga.color)
                    Spacer()
                    Text(manga.formattedDateString)
                        .lineLimit(1)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 1)
            }
            .drawingGroup()
        }
        .padding(.vertical, setting.showsSummaryRowTags ? 5 : 0)
        .padding(.leading, -10)
        .padding(.trailing, -5)
    }
}

private extension MangaDetailCell {
    var width: CGFloat {
        Defaults.ImageSize.rowW
    }
    var height: CGFloat {
        Defaults.ImageSize.rowH
    }

    var category: String {
        manga.category.rawValue.localized()
    }
    var tags: [String] {
        if setting.summaryRowTagsMaximum > 0 {
            return Array(
                manga.tags.prefix(setting.summaryRowTagsMaximum)
            )
        } else {
            return manga.tags
        }
    }
    var tagColor: Color {
        colorScheme == .light
            ? Color(.systemGray5)
            : Color(.systemGray4)
    }
}

struct MangaDetailCell_Previews: PreviewProvider {
    static var previews: some View {
        MangaDetailCell(manga: .preview, setting: Setting())
            .preferredColorScheme(.dark)
    }
}
