import AppTools
import SwiftUI
import AppModels
import AppComponents
import Kingfisher
import Sharing

public struct GalleryHistoryCell: View {
    @SharedReader(.setting) private var setting: Setting
    private let gallery: Gallery

    public init(gallery: Gallery) {
        self.gallery = gallery
    }

    private var displayTitle: String {
        setting.displaysJapaneseTitle ? gallery.titleJpn ?? gallery.trimmedTitle : gallery.trimmedTitle
    }

    public var body: some View {
        HStack(spacing: 20) {
            KFImage(gallery.coverURL)
                .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect)) }.defaultModifier()
                .scaledToFill().frame(width: Defaults.ImageSize.rowW * 0.75, height: Defaults.ImageSize.rowH * 0.75)
                .cornerRadius(2)
            VStack(alignment: .leading) {
                Text(displayTitle).bold().lineLimit(2).fixedSize(horizontal: false, vertical: true)
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
