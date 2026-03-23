//
//  GalleryHistoryCell.swift
//  EhPanda
//

import SwiftUI
import Kingfisher

struct GalleryHistoryCell: View {
    @ObservedObject private var downloadStore = DownloadBadgeStore.shared

    private let gallery: Gallery

    init(gallery: Gallery) {
        self.gallery = gallery
    }

    private var resolvedCoverURL: URL? {
        downloadStore.resolvedCoverURL(for: gallery)
    }

    var body: some View {
        HStack(spacing: 20) {
            KFImage(resolvedCoverURL)
                .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect)) }.defaultModifier()
                .scaledToFill().frame(width: Defaults.ImageSize.rowW * 0.75, height: Defaults.ImageSize.rowH * 0.75)
                .cornerRadius(2)
            VStack(alignment: .leading) {
                Text(gallery.trimmedTitle).bold().lineLimit(2).fixedSize(horizontal: false, vertical: true)
                if let uploader = gallery.uploader {
                    Text(uploader).foregroundColor(.secondary).lineLimit(1)
                }
                Spacer()
                RatingView(rating: gallery.rating).foregroundColor(.primary)
            }
            .font(.caption)
            Spacer()
        }
        .frame(width: Defaults.ImageSize.rowW * 3, height: Defaults.ImageSize.rowH * 0.75)
    }
}

struct GalleryHistoryCell_Previews: PreviewProvider {
    static var previews: some View {
        GalleryHistoryCell(gallery: .preview)
    }
}
