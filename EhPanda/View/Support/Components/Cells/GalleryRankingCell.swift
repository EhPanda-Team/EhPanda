//
//  GalleryRankingCell.swift
//  EhPanda
//

import SwiftUI
import Kingfisher

struct GalleryRankingCell: View {
    @ObservedObject private var downloadStore = DownloadBadgeStore.shared

    private let gallery: Gallery
    private let ranking: Int
    private let downloadBadge: DownloadBadge

    init(gallery: Gallery, ranking: Int, downloadBadge: DownloadBadge = .none) {
        self.gallery = gallery
        self.ranking = ranking
        self.downloadBadge = downloadBadge
    }

    private var resolvedCoverURL: URL? {
        downloadStore.resolvedCoverURL(for: gallery)
    }

    var body: some View {
        HStack {
            KFImage(resolvedCoverURL)
                .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect)) }.defaultModifier()
                .scaledToFill().frame(width: Defaults.ImageSize.rowW * 0.75, height: Defaults.ImageSize.rowH * 0.75)
                .cornerRadius(2)
            Text(String(ranking)).fontWeight(.medium).font(.title2).padding(.horizontal)
            VStack(alignment: .leading) {
                Text(gallery.trimmedTitle).bold().lineLimit(2).fixedSize(horizontal: false, vertical: true)
                DownloadBadgeLabel(badge: downloadBadge, compact: true)
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
