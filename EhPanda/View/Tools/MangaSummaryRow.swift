//
//  MangaSummaryRow.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/16.
//

import SwiftUI
import Kingfisher

struct MangaSummaryRow: View, StoreAccessor {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) private var colorScheme

    let manga: Manga

    var body: some View {
        HStack {
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
                    .foregroundColor(.primary)
                Text(manga.uploader ?? "")
                    .lineLimit(1)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                if setting?.showSummaryRowTags == true,
                   !tags.isEmpty
                {
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
                        .foregroundColor(.yellow)
                    if let language = manga.language {
                        Spacer()
                        Text(language.rawValue.localized())
                            .lineLimit(1)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                HStack(alignment: .bottom) {
                    if isTokenMatched {
                        Text(category)
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .font(.footnote)
                            .foregroundColor(.white)
                            .padding(.vertical, 1)
                            .padding(.horizontal, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 2)
                                    .foregroundColor(manga.color)
                            )
                    }
                    Spacer()
                    Text(manga.formattedDateString)
                        .lineLimit(1)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 1)
            }
            .padding(10)
            .drawingGroup()
        }
        .background(Color(.systemGray6))
        .cornerRadius(3)
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
        if setting?.translateCategory == true {
            return manga.category.rawValue.localized()
        } else {
            return manga.category.rawValue
        }
    }
    var tags: [String] {
        if setting?.summaryRowTagsMaximumActivated == true {
            return Array(
                manga.tags
                    .prefix(
                        setting?.summaryRowTagsMaximum ?? 5
                    )
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
        Placeholder(
            style: .activity,
            width: width,
            height: height
        )
    }

}
