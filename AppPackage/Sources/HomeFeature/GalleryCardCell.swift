import SwiftUI
import AppModels
import AppComponents
import Colorful
import Kingfisher
import UIImageColors
import AppTools
import Sharing

public struct GalleryCardCell: View {
    @Environment(\.colorScheme) private var colorScheme
    @SharedReader(.setting) private var setting: Setting

    private let currentID: String
    private let colors: [Color]
    private let webImageSuccessAction: (RetrieveImageResult) -> Void

    private let gallery: Gallery

    private let animation: Animation =
        .interpolatingSpring(stiffness: 50, damping: 1).speed(0.2)

    public init(
        gallery: Gallery, currentID: String, colors: [Color],
        webImageSuccessAction: @escaping (RetrieveImageResult) -> Void
    ) {
        self.gallery = gallery
        self.currentID = currentID
        self.colors = colors
        self.webImageSuccessAction = webImageSuccessAction
    }

    private var animated: Bool {
        guard colorScheme == .dark else { return false }
        return gallery.gid == currentID
    }
    private var title: String {
        let rawTitle = setting.displaysJapaneseTitle ? gallery.titleJpn ?? gallery.title : gallery.title
        var trimmed = rawTitle
        if let range = trimmed.range(of: "|") {
            trimmed = String(trimmed[..<range.lowerBound])
        }
        trimmed = trimmed.barcesAndSpacesRemoved
        guard !DeviceUtil.isPad, trimmed.count > 20 else {
            return rawTitle
        }
        return trimmed
    }

    public var body: some View {
        ZStack {
            Color.gray.opacity(0.2)
            ColorfulView(animated: animated, animation: animation, colors: colors)
                .id(currentID + animated.description)
            HStack {
                KFImage(gallery.coverURL)
                    .placeholder { Placeholder(style: .activity(ratio: Defaults.ImageSize.headerAspect)) }
                    .onSuccess(webImageSuccessAction).defaultModifier().scaledToFill()
                    .frame(width: Defaults.ImageSize.headerW, height: Defaults.ImageSize.headerH)
                    .cornerRadius(5)
                VStack(alignment: .leading) {
                    Text(title).font(.title3.bold()).lineLimit(4)
                    Spacer()
                    RatingView(rating: gallery.rating).foregroundColor(.yellow)
                }
                .padding(.leading, 15)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 20)
        }
        .frame(width: Defaults.FrameSize.cardCellWidth).cornerRadius(15)
    }
}

struct GalleryCardCell_Previews: PreviewProvider {
    static var previews: some View {
        let gallery = Gallery.preview
        GalleryCardCell(
            gallery: gallery, currentID: gallery.gid,
            colors: ColorfulView.defaultColorList,
            webImageSuccessAction: { _ in }
        )
        .previewLayout(.fixed(width: 300, height: 206)).padding()
    }
}
