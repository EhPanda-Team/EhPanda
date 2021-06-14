//
//  MangaSummaryRow.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/16.
//

import SwiftUI
import Kingfisher

struct MangaSummaryRow: View {
    @Environment(\.colorScheme) private var colorScheme

    private let manga: Manga
    private let setting: Setting

    init(
        manga: Manga,
        setting: Setting
    ) {
        self.manga = manga
        self.setting = setting
    }

    var body: some View {
        HStack(spacing: 10) {
            KFImage(URL(string: manga.coverURL))
                .placeholder(placeholder)
                .loadImmediately()
                .resizable()
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
                if setting.showSummaryRowTags, !tags.isEmpty {
                    TagCloudView(
                        tag: MangaTag(
                            category: .artist,
                            content: tags
                        ),
                        font: .caption2,
                        textColor: .secondary,
                        backgroundColor: tagColor,
                        paddingV: 2,
                        paddingH: 4
                    )
                }
                HStack {
                    RatingView(rating: manga.rating)
                        .font(.system(size: 12))
                        .foregroundStyle(.yellow)
                    Spacer()
                    Text(manga.language?.rawValue.localized() ?? "")
                        .lineLimit(1)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                HStack(alignment: .bottom) {
                    Text(category)
                        .fontWeight(.bold)
                        .lineLimit(1)
                        .font(.footnote)
                        .foregroundStyle(.white)
                        .padding(.vertical, 1)
                        .padding(.horizontal, 3)
                        .background(
                            RoundedRectangle(cornerRadius: 2)
                                .foregroundStyle(manga.color)
                        )
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
        .padding(.vertical, setting.showSummaryRowTags ? 5 : 0)
        .padding(.leading, -10)
        .padding(.trailing, -5)
    }
}

private extension MangaSummaryRow {
    var width: CGFloat {
        Defaults.ImageSize.rowW
    }
    var height: CGFloat {
        Defaults.ImageSize.rowH
    }

    var category: String {
        if setting.translateCategory {
            return manga.category.rawValue.localized()
        } else {
            return manga.category.rawValue
        }
    }
    var tags: [String] {
        if setting.summaryRowTagsMaximumActivated {
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
    func placeholder() -> some View {
        Placeholder(style: .activity(width: width, height: height))
    }
}
