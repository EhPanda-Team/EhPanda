//
//  MangaThumbnailCell.swift
//  EhPanda
//
//  Created by 荒木辰造 on 2021/08/02.
//

import SwiftUI
import Kingfisher

struct MangaThumbnailCell: View {
    @Environment(\.colorScheme) private var colorScheme

    private let manga: Manga
    private let setting: Setting

    init(manga: Manga, setting: Setting) {
        self.manga = manga
        self.setting = setting
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            KFImage(URL(string: manga.coverURL))
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
                                color: manga.color,
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
                Text(manga.title).bold()
                    .font(.callout)
                    .lineLimit(3)
                if setting.showsSummaryRowTags, !manga.tags.isEmpty {
                    TagCloudView(
                        tag: MangaTag(
                            category: .artist,
                            content: manga.tags
                        ),
                        font: .caption2,
                        textColor: .secondary,
                        backgroundColor: tagColor,
                        paddingV: 2, paddingH: 4
                    )
                }
                HStack {
                    RatingView(rating: manga.rating)
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Spacer()
                    Text(manga.language?.languageAbbr ?? "")
                        .foregroundStyle(.secondary)
                        .font(.footnote)
                        .lineLimit(1)
                }
                .padding(.top, 1)
            }
            .padding()
        }
        .background(backgroundColor)
        .cornerRadius(15)
    }
}

private extension MangaThumbnailCell {
    var category: String {
        if setting.translatesCategory {
            return manga.category.rawValue.localized()
        } else {
            return manga.category.rawValue
        }
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

struct MangaThumbnailCell_Previews: PreviewProvider {
    static var previews: some View {
        MangaThumbnailCell(manga: .preview, setting: Setting())
            .preferredColorScheme(.dark)
    }
}
