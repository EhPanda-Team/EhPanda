//
//  MangaWaterfallCell.swift
//  MangaWaterfallCell
//
//  Created by 荒木辰造 on 2021/08/02.
//

import SwiftUI
import Kingfisher

struct MangaWaterfallCell: View {
    private let manga: Manga
    private let setting: Setting

    var category: String {
        if setting.translatesCategory {
            return manga.category.rawValue.localized()
        } else {
            return manga.category.rawValue
        }
    }

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
                HStack {
                    RatingView(rating: manga.rating)
                        .foregroundColor(.yellow)
                        .font(.caption)
                    Spacer()
                    Text(manga.language?.languageAbbr ?? "")
                        .lineLimit(1)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 1)
            }
            .padding()
        }
        .background(Color(.systemGray6))
        .cornerRadius(15)
    }
}

struct MangaWaterfallCell_Previews: PreviewProvider {
    static var previews: some View {
        MangaWaterfallCell(manga: .preview, setting: Setting())
            .preferredColorScheme(.dark)
    }
}
