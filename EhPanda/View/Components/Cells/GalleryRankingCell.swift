//
//  GalleryRankingCell.swift
//  EhPanda
//
//  Created by 荒木辰造 on R 3/12/14.
//

import SwiftUI
import Kingfisher

struct GalleryRankingCell: View {
    private let gallery: Gallery
    private let ranking: Int

    init(gallery: Gallery, ranking: Int) {
        self.gallery = gallery
        self.ranking = ranking
    }

    var body: some View {
        HStack {
            KFImage(URL(string: gallery.coverURL))
                .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect)) }
                .defaultModifier().scaledToFill()
                .frame(width: Defaults.ImageSize.rowW * 0.75, height: Defaults.ImageSize.rowH * 0.75).cornerRadius(2)
            Text(String(ranking)).fontWeight(.medium).font(.title2).padding(.horizontal)
            VStack(alignment: .leading) {
                Text(gallery.title).bold().lineLimit(2)
                if let uploader = gallery.uploader {
                    Text(uploader).foregroundColor(.secondary).lineLimit(1)
                }
            }
            .font(.caption)
            Spacer()
        }
    }
}

struct GalleryRankingCell_Previews: PreviewProvider {
    static var previews: some View {
        GalleryRankingCell(gallery: .preview, ranking: 1)
            .previewLayout(.fixed(width: 300, height: 100))
            .preferredColorScheme(.dark)
    }
}
