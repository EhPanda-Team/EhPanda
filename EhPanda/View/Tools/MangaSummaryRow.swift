//
//  MangaSummaryRow.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/16.
//

import SwiftUI
import Kingfisher

struct MangaSummaryRow: View {
    @EnvironmentObject var store: Store
    @Environment(\.colorScheme) var colorScheme
    
    var setting: Setting? {
        store.appState.settings.setting
    }
    var width: CGFloat {
        Defaults.ImageSize.rowW
    }
    var height: CGFloat {
        Defaults.ImageSize.rowH
    }
    
    var category: String {
        if setting?.translateCategory == true {
            return manga.category.rawValue.lString()
        } else {
            return manga.category.rawValue.uppercased()
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
    var modifier: KFImageModifier {
        KFImageModifier(
            targetScale:
                Defaults
                .ImageSize
                .rowScale
        )
    }
    func placeholder() -> some View {
        Placeholder(
            style: .activity,
            width: width,
            height: height
        )
    }
    
    let manga: Manga
    
    var body: some View {
        HStack {
            KFImage(URL(string: manga.coverURL))
                .placeholder(placeholder)
                .imageModifier(modifier)
                .resizable()
                .scaledToFit()
                .frame(width: width, height: height)
            VStack(alignment: .leading) {
                Text(manga.title)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(manga.uploader == nil ? 2 : 1)
                if let uploader = manga.uploader {
                    Text(uploader)
                        .lineLimit(1)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                if setting?.showSummaryRowTags == true,
                   !tags.isEmpty
                {
                    TagCloudView(
                        tag: MangaTag(category: .artist, content: tags),
                        font: .caption2,
                        textColor: .secondary,
                        backgroundColor: tagColor,
                        paddingV: 2,
                        paddingH: 4,
                        onTapAction: { _ in }
                    )
                }
                HStack {
                    RatingView(rating: manga.rating)
                        .font(.system(size: 12))
                        .foregroundColor(.yellow)
                    if let language = manga.language {
                        Spacer()
                        Text(language.rawValue.lString())
                            .lineLimit(1)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                HStack(alignment: .bottom) {
                    if exx {
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
                    Text(manga.publishedTime)
                        .lineLimit(1)
                        .font(.footnote)
                        .foregroundColor(.secondary)
                }
                .padding(.top, 1)
            }.padding(10)
        }
        .background(Color(.systemGray6))
        .cornerRadius(3)
    }
}
