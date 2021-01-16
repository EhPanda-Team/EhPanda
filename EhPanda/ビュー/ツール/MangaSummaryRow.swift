//
//  MangaSummaryRow.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/01/16.
//

import SwiftUI
import SDWebImageSwiftUI

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
    
    var tags: [String] {
        if let setting = setting,
           setting.showSummaryRowTags
        {
            if setting.summaryRowTagsMaximumActivated {
                return Array(
                    manga.tags
                        .prefix(
                            setting.summaryRowTagsMaximum
                        )
                )
            } else {
                return manga.tags
            }
        } else {
            return []
        }
    }
    var tagColor: Color {
        colorScheme == .light
            ? Color(.systemGray5)
            : Color(.systemGray4)
    }
    
    let manga: Manga
    
    var body: some View {
        HStack {
            WebImage(url: URL(string: manga.coverURL),
                     options: [.retryFailed, .handleCookies])
                .resizable()
                .placeholder {
                    Rectangle()
                        .fill(Color(.systemGray5))
                        .frame(width: width, height: height)
                }
                .indicator(.activity)
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
                if !tags.isEmpty {
                    TagCloudView(
                        tag: Tag(category: .artist, content: tags),
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
                    if let language = manga.language {
                        Spacer()
                        Text(language.translatedLanguage.lString())
                            .lineLimit(1)
                            .font(.footnote)
                            .foregroundColor(.secondary)
                    }
                }
                HStack(alignment: .bottom) {
                    if exx {
                        Text(manga.jpnCategory.lString())
                            .fontWeight(.bold)
                            .lineLimit(1)
                            .font(.footnote)
                            .foregroundColor(.white)
                            .padding(.init(top: 1, leading: 3, bottom: 1, trailing: 3))
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
